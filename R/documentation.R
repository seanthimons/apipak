roxygen_prose <- function(text) {
  text <- gsub('\\', '\\\\', text, fixed = TRUE)
  for (character in c('{', '}', '%')) {
    text <- gsub(character, paste0('\\', character), text, fixed = TRUE)
  }
  gsub('@', '@@', text, fixed = TRUE)
}

validate_documentation <- function(docs) {
  config_fields(
    docs,
    c(
      'title',
      'description',
      'parameters',
      'return',
      'lifecycle',
      'tags',
      'examples'
    ),
    'docs'
  )
  for (name in intersect(
    names(docs),
    c('title', 'description', 'return', 'lifecycle')
  )) {
    config_string(docs[[name]], paste('docs', name))
  }
  if (
    !is.null(docs$lifecycle) &&
      !docs$lifecycle %in%
        c(
          'experimental',
          'stable',
          'maturing',
          'superseded',
          'deprecated',
          'defunct',
          'questioning',
          'soft-deprecated'
        )
  ) {
    stop('Invalid lifecycle policy')
  }
  for (field in intersect(names(docs), c('parameters', 'tags'))) {
    config_fields(docs[[field]], names(docs[[field]]), paste('docs', field))
    for (value in docs[[field]]) {
      config_string(value, paste('docs', field))
    }
  }
  # Built-in code/structural tags cannot enter through a custom metadata map.
  builtins <- sub(
    '^roxy_tag_parse.roxy_tag_',
    '',
    grep(
      '^roxy_tag_parse.roxy_tag_',
      ls(asNamespace('roxygen2'), all.names = TRUE),
      value = TRUE
    )
  )
  forbidden <- setdiff(builtins, c('family', 'keywords', 'seealso', 'aliases'))
  if (
    any(names(docs$tags) %in% forbidden) ||
      any(!grepl('^[A-Za-z][A-Za-z0-9]*$', names(docs$tags)))
  ) {
    stop('Unsafe documentation tag')
  }
  if ('examples' %in% names(docs)) {
    if (!is.list(docs$examples) || !is.null(names(docs$examples))) {
      stop('docs examples must be a sequence of input maps')
    }
    for (example in docs$examples) {
      config_fields(example, names(example), 'example inputs')
    }
  }
  invisible(docs)
}

operation_documentation <- function(op, policy = list()) {
  validate_documentation(policy)
  parameters <- parameter_names(op$parameters)
  if (length(setdiff(names(policy$parameters), parameters))) {
    stop('Documentation references missing public parameter')
  }
  prose <- function(text) {
    text <- roxygen_prose(text)
    if (!is.null(policy$lifecycle)) {
      for (character in c('[', ']')) {
        text <- gsub(character, paste0('\\', character), text, fixed = TRUE)
      }
      # Convert code spans to inert Rd before Markdown can evaluate inline R.
      text <- stringr::str_replace_all(text, '`+[^`]+`+', function(span) {
        paste0('\\code{', sub('`+$', '', sub('^`+', '', span)), '}')
      })
      text <- gsub('`', '\\verb{`}', text, fixed = TRUE)
    }
    text
  }
  docs <- vapply(
    seq_along(parameters),
    function(i) {
      paste0(
        '@param ',
        parameters[[i]],
        ' ',
        prose(
          policy$parameters[[parameters[[i]]]] %or%
            op$parameters[[i]]$schema$description %or%
            op$parameters[[i]]$name
        )
      )
    },
    character(1)
  )
  if (!is.null(op$body)) {
    docs <- c(docs, '@param body Request body.')
  }
  text <- c(
    prose(policy$title %or% op$summary),
    '',
    if (is.null(policy$lifecycle)) '@noMd' else '@md',
    if (!is.null(policy$lifecycle) || !is.null(policy$description)) {
      '@description'
    },
    if (!is.null(policy$lifecycle)) {
      paste0('`r lifecycle::badge(', r_literal(policy$lifecycle), ')`')
    },
    if (!is.null(policy$lifecycle) && !is.null(policy$description)) '',
    if (!is.null(policy$description)) prose(policy$description),
    docs,
    paste0(
      '@return ',
      prose(
        policy$return %or%
          'Decoded response returned by the client request helper.'
      )
    ),
    vapply(
      names(policy$tags),
      function(name) paste0('@', name, ' ', prose(policy$tags[[name]])),
      character(1)
    ),
    '@export',
    if (length(policy$examples)) {
      c(
        '@examples',
        '\\dontrun{',
        vapply(
          policy$examples,
          function(inputs) {
            if (
              length(setdiff(
                names(inputs),
                c(parameters, if (!is.null(op$body)) 'body')
              ))
            ) {
              stop('Example references missing public parameter')
            }
            paste0(
              op$name,
              '(',
              paste(
                vapply(
                  names(inputs),
                  function(name) {
                    value <- config_data(inputs[[name]])
                    index <- match(name, parameters)
                    if (
                      !is.na(index) &&
                        is.list(value) &&
                        op$parameters[[index]]$public_type %or%
                          '' %in%
                          c('character', 'logical', 'integer', 'numeric')
                    ) {
                      if (
                        !is.null(names(value)) ||
                          any(vapply(value, is.list, logical(1)))
                      ) {
                        stop(
                          'Primitive vector example must be a sequence of scalar values'
                        )
                      }
                      value <- unlist(value, use.names = FALSE)
                    }
                    paste0(
                      name,
                      ' = ',
                      r_literal(value)
                    )
                  },
                  character(1)
                ),
                collapse = ', '
              ),
              ')'
            )
          },
          character(1)
        ),
        '}'
      )
    }
  )
  paste(
    paste0(
      "#' ",
      strsplit(paste(text, collapse = '\n'), '\n', fixed = TRUE)[[1L]]
    ),
    collapse = '\n'
  )
}

document_output <- function(root, desired, remove = character()) {
  stage <- tempfile('apipak-documentation-')
  dir.create(stage)
  on.exit(unlink(stage, recursive = TRUE), add = TRUE)
  inputs <- intersect(
    c('R', 'man', 'DESCRIPTION', 'NAMESPACE', 'data', 'inst', 'LICENSE'),
    list.files(root)
  )
  if (!all(c('R', 'DESCRIPTION') %in% inputs)) {
    stop('Documentation requires a package DESCRIPTION and R directory')
  }
  if (!all(file.copy(file.path(root, inputs), stage, recursive = TRUE))) {
    stop('Cannot stage documentation inputs')
  }
  for (name in remove) {
    staged <- project_path(stage, name)
    if (file.exists(staged)) unlink(staged)
  }
  for (name in names(desired)) {
    path <- project_path(stage, name)
    dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
    writeLines(enc2utf8(desired[[name]]), path, useBytes = TRUE)
  }
  script <- file.path(stage, 'document.R')
  writeLines(
    paste0(
      'roxygen2::roxygenise(',
      r_literal(stage),
      ", roclets = c('rd', 'namespace'))"
    ),
    script
  )
  log <- file.path(stage, 'documentation.log')
  status <- system2(
    file.path(R.home('bin'), 'Rscript'),
    shQuote(script),
    stdout = log,
    stderr = log
  )
  if (status != 0L) {
    stop(
      'Documentation failed: ',
      paste(readLines(log, warn = FALSE), collapse = '\n')
    )
  }
  files <- c(
    'NAMESPACE',
    paste0(
      'man/',
      list.files(file.path(stage, 'man'), '\\.(Rd|svg)$', recursive = TRUE)
    )
  )
  files <- files[file.exists(file.path(stage, files))]
  owners <- attr(desired, 'operations') %or% list()
  for (name in files) {
    if (endsWith(name, '.Rd')) {
      tools::parse_Rd(file.path(stage, name), encoding = 'UTF-8')
      sources <- unique(unlist(stringr::str_extract_all(
        head(readLines(file.path(stage, name), warn = FALSE), 3L),
        'R/[^ ,\\r\\n]+\\.R'
      )))
      selected_sources <- intersect(sources, names(owners))
      if (!length(selected_sources)) {
        next
      }
      if (length(setdiff(sources, selected_sources))) {
        stop('Mixed documentation includes an unowned source: ', name)
      }
      owners[[name]] <- unique(unlist(
        owners[selected_sources],
        use.names = FALSE
      ))
    } else if (identical(name, 'NAMESPACE')) {
      owners[[name]] <- unique(unlist(owners, use.names = FALSE))
    } else if (file.exists(file.path(root, name))) {
      # Existing shared figures are client assets, not newly adopted output.
      next
    } else {
      owners[[name]] <- unique(unlist(owners, use.names = FALSE))
    }
    desired[[name]] <- file_text(file.path(stage, name))
  }
  attr(desired, 'operations') <- owners
  desired
}
