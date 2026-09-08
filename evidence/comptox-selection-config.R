comptox_selection_config <- function(
  root,
  support = 'evidence/schema-support.rds',
  write = FALSE
) {
  root <- normalizePath(root, winslash = '/', mustWork = TRUE)
  records <- readRDS(support)
  inventory <- do.call(c, unname(lapply(records, `[[`, 'inventory')))
  groups <- split(inventory, vapply(inventory, `[[`, character(1), 'service'))
  config <- new.env(parent = baseenv())
  sys.source(file.path(root, 'dev/endpoint_eval/00_config.R'), config)
  output <- list()
  for (id in names(groups)) {
    operations <- groups[[id]]
    prefix <- operations[[1L]]$prefix
    service_id <- if (id == 'ct') 'ctx' else id
    files <- sort(unique(vapply(
      operations,
      function(x) paste0('schema/', basename(x$source)),
      character(1)
    )))
    selected <- Filter(function(x) x$status != 'excluded', operations)
    names <- stats::setNames(
      lapply(selected, `[[`, 'name'),
      vapply(selected, `[[`, character(1), 'key')
    )
    exclusions <- if (prefix == 'chemi') {
      as.list(config$ENDPOINT_PATTERNS_TO_EXCLUDE)
    } else {
      list()
    }
    if (prefix == 'epi') {
      exclusions <- as.list(c(
        '^/api$',
        '^/api/download',
        '^/api/draw-chemical',
        '^/api/ecosar/test'
      ))
    }
    service <- list(
      id = service_id,
      schemas = list(files = as.list(files)),
      selection = list(methods = list('GET', 'POST'), exclude = exclusions),
      helper = if (prefix == 'chemi') {
        'generic_chemi_request'
      } else {
        'generic_request'
      },
      policy_version = 'comptox-maintenance-1',
      hook_config = 'inst/hook_config.yml',
      names = names
    )
    output[[paste0('apis/', service_id, '.yml')]] <- yaml::as.yaml(service)
  }
  output[['apipak.yml']] <- yaml::as.yaml(list(
    config_version = 1L,
    package = 'ComptoxR',
    services = as.list(names(output))
  ))
  if (write) {
    for (path in names(output)) {
      destination <- file.path(root, path)
      if (file.exists(destination)) {
        stop('Selection seed refuses an existing file: ', path)
      }
    }
    for (path in names(output)) {
      writeLines(output[[path]], file.path(root, path), useBytes = TRUE)
    }
  }
  project <- apipak::load_project(root)
  parsed <- lapply(project$services, function(service) {
    apipak::read_operations(service$files, service$policy)
  })
  actual <- do.call(c, lapply(parsed, `[[`, 'inventory'))
  actual <- Filter(function(x) x$status != 'excluded', actual)
  expected <- Filter(function(x) x$status != 'excluded', inventory)
  keys <- function(x) {
    sort(unname(vapply(
      x,
      function(op) paste(if (op$service == 'ct') 'ctx' else op$service, op$key),
      character(1)
    )))
  }
  stopifnot(identical(keys(actual), keys(expected)), length(actual) == 343L)
  cat(
    'Full service YAML selection: all 343 identities match; request/documentation mappings are pending.\n'
  )
  invisible(output)
}
if (sys.nframe() == 0L) {
  comptox_selection_config(commandArgs(trailingOnly = TRUE)[[1L]])
}
