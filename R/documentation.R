roxygen_prose <- function(text) {
  text <- gsub('\\', '\\\\', text, fixed = TRUE)
  for (character in c('{', '}', '%')) {
    text <- gsub(character, paste0('\\', character), text, fixed = TRUE)
  }
  gsub('@', '@@', text, fixed = TRUE)
}

operation_documentation <- function(op) {
  parameters <- parameter_names(op$parameters)
  docs <- vapply(
    seq_along(parameters),
    function(i) {
      paste0(
        '@param ',
        parameters[[i]],
        ' ',
        roxygen_prose(
          op$parameters[[i]]$schema$description %or% op$parameters[[i]]$name
        )
      )
    },
    character(1)
  )
  if (!is.null(op$body)) {
    docs <- c(docs, '@param body Request body.')
  }
  text <- c(
    roxygen_prose(op$summary),
    '',
    '@noMd',
    docs,
    '@return Decoded response returned by the client request helper.',
    '@export'
  )
  paste(
    paste0("#' ", unlist(strsplit(text, '\n', fixed = TRUE))),
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
    paste0('man/', list.files(file.path(stage, 'man'), '\\.Rd$'))
  )
  files <- files[file.exists(file.path(stage, files))]
  for (name in files) {
    if (endsWith(name, '.Rd')) {
      tools::parse_Rd(file.path(stage, name))
    }
    desired[[name]] <- file_text(file.path(stage, name))
  }
  desired
}
