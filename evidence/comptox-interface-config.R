comptox_interface_config <- function(root, write = FALSE) {
  root <- normalizePath(root, winslash = '/', mustWork = TRUE)
  mappings <- readRDS('evidence/interface-probe.rds')
  correction <- readRDS('evidence/epi-batch-diagnosis.rds')$settings
  mappings[['epi POST /api/submit/batch']]$settings <- correction
  stopifnot(
    length(mappings) == 152L,
    all(vapply(
      mappings,
      function(x) x$status == 'mapped request shape',
      logical(1)
    ))
  )
  callbacks <- new.env(parent = baseenv())
  sys.source(file.path(root, 'dev/apipak_callbacks.R'), callbacks)
  services <- list()
  for (id in c('ctx', 'epi')) {
    path <- file.path(root, 'apis', paste0(id, '.yml'))
    service <- getFromNamespace('config_data', 'apipak')(
      getFromNamespace('read_config_yaml', 'apipak')(path)
    )
    prefix <- if (id == 'ctx') 'ct ' else 'epi '
    selected <- mappings[startsWith(names(mappings), prefix)]
    operations <- stats::setNames(
      lapply(selected, `[[`, 'settings'),
      substring(names(selected), nchar(prefix) + 1L)
    )
    if (write && !is.null(service$operations)) {
      stop('Interface policy already exists; refusing to replace it')
    }
    if (write) {
      service$operations <- operations
      yaml::write_yaml(service, path, precision = 17)
    } else {
      # Compare normalized data, including doubles at full precision.
      stopifnot(identical(service$operations, operations))
    }
    services[[id]] <- service
  }
  project <- apipak::load_project(root, callbacks = callbacks)
  count <- 0L
  for (id in names(services)) {
    service <- project$services[[id]]
    operations <- apipak::read_operations(
      service$files,
      service$policy
    )$operations
    for (op in operations) {
      configured <- getFromNamespace('configure_operation', 'apipak')(
        op,
        service
      )
      parse(
        text = apipak::render_operation(configured$operation, configured$spec)
      )
      count <- count + 1L
    }
  }
  stopifnot(count == 152L)
  cat(
    'Client interface YAML: 152 validated mappings, including the diagnosed EPI request correction.\n'
  )
  invisible(project)
}
if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  comptox_interface_config(args[[1L]], write = '--write' %in% args)
}
