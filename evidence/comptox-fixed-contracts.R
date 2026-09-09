comptox_fixed_contracts <- function(root, write = FALSE) {
  root <- normalizePath(root, winslash = '/', mustWork = TRUE)
  records <- c(
    readRDS('evidence/contract-probe.rds'),
    readRDS('evidence/chemi-contract-probe.rds')
  )
  stopifnot(
    length(records) == 342L,
    all(vapply(
      records,
      function(x) x$status == 'successful parity' && !is.null(x$result),
      logical(1)
    ))
  )
  callbacks <- new.env(parent = baseenv())
  sys.source(file.path(root, 'dev/apipak_callbacks.R'), callbacks)
  project <- apipak::load_project(root, callbacks = callbacks)
  config <- getFromNamespace('config_data', 'apipak')(getFromNamespace(
    'read_config_yaml',
    'apipak'
  )(file.path(root, 'apipak.yml')))
  for (relative in config$services) {
    path <- file.path(root, relative)
    service <- getFromNamespace('config_data', 'apipak')(getFromNamespace(
      'read_config_yaml',
      'apipak'
    )(path))
    prefix <- paste0(if (service$id == 'ctx') 'ct' else service$id, ' ')
    selected <- records[startsWith(names(records), prefix)]
    fixed <- stats::setNames(
      lapply(selected, function(record) {
        calls <- record$traffic
        stopifnot(length(calls) > 0L)
        if (record$name == 'epi_submit_batch') {
          # The separately verified public EPI contract corrects the legacy route.
          stopifnot(
            length(calls) == 1L,
            calls[[1L]]$helper == 'generic_request'
          )
          calls[[1L]]$arguments$body <- list(calls[[1L]]$arguments$body)
          calls[[1L]]$arguments$server <- 'epi_burl'
          calls[[1L]]$arguments$auth <- FALSE
        }
        list(
          inputs = record$inputs,
          calls = calls,
          result = record$result,
          environment = list(batch_limit = '200')
        )
      }),
      vapply(selected, `[[`, character(1), 'name')
    )
    fixture <- paste0('tests/testthat/fixtures/apipak/', service$id, '.rds')
    destination <- file.path(root, fixture)
    if (file.exists(destination)) {
      original <- readRDS(destination)
      without_environment <- lapply(fixed, function(x) {
        x$environment <- NULL
        x
      })
      if (write && identical(original, without_environment)) {
        # Only the verified test environment changes; preserve every expected value.
        saveRDS(fixed, destination, version = 3L)
      } else {
        stopifnot(identical(original, fixed))
      }
    } else if (write) {
      dir.create(dirname(destination), recursive = TRUE, showWarnings = FALSE)
      saveRDS(fixed, destination, version = 3L)
    } else {
      stop('Missing frozen contract fixture: ', fixture)
    }
    service$contracts_file <- fixture
    text <- sub('\n$', '', yaml::as.yaml(service, precision = 17))
    if (write) {
      writeLines(enc2utf8(text), path, useBytes = TRUE)
    } else {
      stopifnot(identical(getFromNamespace('file_text', 'apipak')(path), text))
    }
  }
  loaded <- apipak::load_project(root, callbacks = callbacks)
  stopifnot(
    sum(vapply(loaded$services, function(x) length(x$contracts), integer(1))) ==
      343L
  )
  cat(
    '343 independent fixed contracts: frozen baseline call sequences and successful typed results, plus the public resolver POST; EPI correction recorded separately.\n'
  )
  invisible(loaded)
}
if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  comptox_fixed_contracts(args[[1L]], '--write' %in% args)
}
