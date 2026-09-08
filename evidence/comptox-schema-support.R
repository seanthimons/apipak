comptox_schema_support <- function(
  root,
  baseline = 'evidence/baseline',
  output = 'evidence/schema-support.rds'
) {
  root <- normalizePath(root, winslash = '/', mustWork = TRUE)
  frozen <- readRDS(file.path(baseline, 'selected-operations.rds'))
  policy <- new.env(parent = baseenv())
  sys.source(file.path(root, 'dev/endpoint_eval/00_config.R'), policy)
  records <- list()
  strip <- getFromNamespace('strip_curly_params', 'apipak')
  for (prefix in c('ct', 'chemi', 'epi')) {
    pattern <- paste0(
      '^',
      if (prefix == 'ct') 'ctx' else prefix,
      '-.*-prod\\.json$'
    )
    files <- list.files(file.path(root, 'schema'), pattern, full.names = TRUE)
    if (prefix == 'chemi') {
      files <- files[!grepl('ui', basename(files), ignore.case = TRUE)]
    }
    for (file in files) {
      slug <- sub('-prod\\.json$', '', basename(file))
      service <- if (prefix == 'chemi') slug else prefix
      document <- jsonlite::read_json(file)
      overrides <- list()
      for (path in names(document$paths)) {
        for (method in intersect(
          names(document$paths[[path]]),
          c('get', 'post', 'put', 'patch', 'delete', 'head', 'options', 'trace')
        )) {
          key <- paste(toupper(method), path)
          route <- if (prefix == 'chemi') {
            path
          } else {
            strip(path, leading_slash = 'remove')
          }
          if (prefix == 'epi') {
            route <- sub('/+$', '', sub('^api/', '', route))
          }
          rows <- which(
            frozen[[prefix]]$method == toupper(method) &
              frozen[[prefix]]$route == route
          )
          if (prefix == 'chemi') {
            rows <- which(
              frozen[[prefix]]$operation_key ==
                paste(
                  sub('^chemi-', '', slug),
                  path,
                  toupper(method),
                  sep = '\034'
                )
            )
          }
          if (length(rows) > 1L) {
            stop('Ambiguous frozen operation: ', file, ' ', key)
          }
          overrides[[key]] <- if (length(rows)) {
            frozen[[prefix]]$fn[[rows]]
          } else {
            make.names(paste(service, key))
          }
        }
      }
      exclusions <- if (prefix == 'chemi') {
        policy$ENDPOINT_PATTERNS_TO_EXCLUDE
      } else {
        character()
      }
      if (prefix == 'epi') {
        exclusions <- '^/api$|^/api/download|^/api/draw-chemical|^/api/ecosar/test'
      }
      result <- apipak::read_operations(
        file,
        list(
          service = service,
          methods = c('GET', 'POST'),
          exclude = exclusions,
          names = overrides
        )
      )
      for (i in seq_along(result$inventory)) {
        key <- result$inventory[[i]]$key
        result$inventory[[i]]$name <- overrides[[key]]
        result$inventory[[i]]$prefix <- prefix
      }
      records[[slug]] <- result
    }
  }
  inventory <- do.call(c, lapply(records, `[[`, 'inventory'))
  selected <- Filter(function(x) x$status != 'excluded', inventory)
  saveRDS(records, output)
  for (prefix in names(frozen)) {
    actual <- vapply(
      Filter(function(x) x$prefix == prefix, selected),
      `[[`,
      character(1),
      'name'
    )
    cat(
      prefix,
      ': current=',
      length(actual),
      ', frozen=',
      nrow(frozen[[prefix]]),
      '\n',
      sep = ''
    )
    if (
      length(actual) != nrow(frozen[[prefix]]) ||
        !setequal(actual, frozen[[prefix]]$fn)
    ) {
      print(list(
        extra = setdiff(actual, frozen[[prefix]]$fn),
        missing = setdiff(frozen[[prefix]]$fn, actual)
      ))
    }
    stopifnot(
      length(actual) == nrow(frozen[[prefix]]),
      setequal(actual, frozen[[prefix]]$fn)
    )
  }
  saveRDS(records, output)
  jsonlite::write_json(
    inventory,
    sub('\\.rds$', '.json', output),
    auto_unbox = TRUE,
    pretty = TRUE
  )
  cat('Selection parity verified against all 343 frozen operations.\n')
  print(table(
    vapply(selected, `[[`, character(1), 'prefix'),
    vapply(selected, `[[`, character(1), 'status')
  ))
  reasons <- vapply(
    Filter(function(x) x$status == 'unsupported', selected),
    `[[`,
    character(1),
    'reason'
  )
  print(sort(table(reasons), decreasing = TRUE))
  invisible(records)
}
if (sys.nframe() == 0L) {
  comptox_schema_support(commandArgs(trailingOnly = TRUE)[[1L]])
}
