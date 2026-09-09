comptox_documentation_probe <- function(root) {
  mappings <- c(
    readRDS('evidence/interface-probe.rds'),
    readRDS('evidence/chemi-interface-probe.rds')
  )
  files <- list()
  results <- list()
  for (id in names(mappings)) {
    mapping <- mappings[[id]]
    if (
      mapping$status != 'mapped request shape' ||
        mapping$ownership$status != 'selected' ||
        identical(mapping$settings$implementation, 'existing')
    ) {
      next
    }
    if (is.null(files[[mapping$file]])) {
      files[[mapping$file]] <- getFromNamespace(
        'tg_find_function_defs_in_file',
        'apipak'
      )(
        file.path(root, 'R', mapping$file),
        documentation = TRUE
      )
    }
    results[[id]] <- tryCatch(
      {
        lines <- sub(
          "^\\s*#' ?",
          '',
          files[[mapping$file]][[mapping$name]]$documentation
        )
        tags <- list(title = character())
        current <- 'title'
        for (line in lines) {
          if (grepl('^@[A-Za-z]', line)) {
            current <- sub('^@([^ ]+).*$', '\\1', line)
            line <- sub('^@[^ ]+ *', '', line)
          }
          tags[[current]] <- c(tags[[current]], line)
        }
        unknown <- setdiff(
          names(tags),
          c(
            'title',
            'description',
            'param',
            'return',
            'export',
            'apiStage',
            'examples'
          )
        )
        if (length(unknown)) {
          stop('Unmapped documentation tags: ', paste(unknown, collapse = ', '))
        }
        combine <- function(x) {
          text <- trimws(paste(x, collapse = '\n'))
          # Source Markdown escaped these brackets; YAML stores their visible text.
          for (character in c('[', ']')) {
            text <- gsub(paste0('\\', character), character, text, fixed = TRUE)
          }
          text
        }
        policy <- list(
          title = combine(tags$title),
          return = combine(tags$return)
        )
        badge <- grep('lifecycle::badge', tags$description, value = TRUE)
        if (length(badge) != 1L) {
          stop('Expected one lifecycle badge')
        }
        policy$lifecycle <- sub(
          '.*badge\\(["\x27]([^"\x27]+)["\x27]\\).*',
          '\\1',
          badge
        )
        description <- combine(tags$description[!tags$description %in% badge])
        if (nzchar(description)) {
          policy$description <- description
        }
        parameters <- list()
        current <- NULL
        for (line in tags$param) {
          name <- sub('^([^ ]+).*$', '\\1', line)
          if (name %in% names(mapping$settings$inputs)) {
            current <- name
            line <- sub('^[^ ]+ *', '', line)
          }
          if (is.null(current)) {
            stop('Unrecognized parameter documentation')
          }
          parameters[[current]] <- c(parameters[[current]], line)
        }
        if (length(parameters)) {
          policy$parameters <- lapply(parameters, combine)
        }
        policy$tags <- list(apiStage = combine(tags$apiStage))
        example <- combine(tags$examples)
        example <- sub('^\\\\dontrun\\{\\s*', '', example)
        example <- sub('\\s*\\}$', '', example)
        input_types <- list()
        if (nzchar(example)) {
          calls <- as.list(parse(text = example))
          policy$examples <- lapply(calls, function(call) {
            if (
              !is.call(call) || !identical(call[[1L]], as.name(mapping$name))
            ) {
              stop('Nontrivial example call')
            }
            args <- as.list(call)[-1L]
            if (
              length(args) &&
                (is.null(names(args)) || any(!nzchar(names(args))))
            ) {
              stop('Positional example')
            }
            for (name in names(args)) {
              value <- args[[name]]
              if (
                is.call(value) &&
                  identical(value[[1L]], as.name('c')) &&
                  !any(vapply(as.list(value)[-1L], is.language, logical(1)))
              ) {
                value <- do.call(c, as.list(value)[-1L])
                input_types[[name]] <<- typeof(value)
                args[[name]] <- as.list(value)
              } else if (is.language(value)) {
                stop('Nonliteral example argument')
              }
            }
            if (!length(args)) {
              args <- stats::setNames(list(), character())
            }
            args
          })
        }
        list(
          status = 'mapped documentation',
          name = mapping$name,
          policy = policy,
          input_types = input_types
        )
      },
      error = function(e) {
        list(status = conditionMessage(e), name = mapping$name)
      }
    )
  }
  saveRDS(results, 'evidence/documentation-probe.rds')
  print(sort(
    table(vapply(results, `[[`, character(1), 'status')),
    decreasing = TRUE
  ))
  for (result in results) {
    if (result$status != 'mapped documentation') {
      cat(result$name, ': ', result$status, '\n', sep = '')
    }
  }
  invisible(results)
}
if (sys.nframe() == 0L) {
  comptox_documentation_probe(commandArgs(trailingOnly = TRUE)[[1L]])
}
