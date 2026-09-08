epi_batch_diagnosis <- function(root) {
  root <- normalizePath(root, winslash = '/', mustWork = TRUE)
  withr::local_envvar(c(
    COMPTOXR_CRAN_SAFE_TESTS = 'true',
    NOT_CRAN = 'false',
    ctx_api_key = NA,
    GITHUB_OUTPUT = NA
  ))
  pkgload::load_all(root, quiet = TRUE)
  namespace <- asNamespace('ComptoxR')
  withr::local_options(list(
    ComptoxR.run_debug = FALSE,
    ComptoxR.run_verbose = FALSE
  ))
  testthat::local_mocked_bindings(
    .endpoint_url = function(server) {
      switch(
        server,
        ctx_burl = 'https://ctx.example.test',
        epi_burl = 'https://epi.example.test/api',
        stop('Unexpected service')
      )
    },
    ct_api_key = function() 'offline-fixture-key',
    .package = 'ComptoxR'
  )
  requests <- list()
  testthat::local_mocked_bindings(
    req_perform = function(req, ...) {
      requests[[length(requests) + 1L]] <<- req
      httr2::response(
        status_code = 200,
        headers = list(`Content-Type` = 'application/json'),
        body = charToRaw(
          '{"count":1,"success":true,"errors":[],"results":[{"chemicalProperties":{"smiles":"CCO"},"parameters":{}}]}'
        )
      )
    },
    .package = 'httr2'
  )

  # The schema independently defines the route and the outer array, not the
  # frozen wrapper's flat object. One input record preserves its public formals.
  schema <- jsonlite::fromJSON(
    file.path(root, 'schema/epi-suite-prod.json'),
    simplifyVector = FALSE
  )
  body_schema <- schema$paths[['/api/submit/batch']]$post$requestBody$content[[
    'application/json'
  ]]$schema
  stopifnot(
    body_schema$type == 'array',
    body_schema$minItems == 1,
    body_schema$maxItems == 100,
    body_schema$items[['$ref']] == '#/components/schemas/BatchEstimateRequest'
  )
  inputs <- list(modules = list('logKow'), smiles = 'CCO')
  expected_body <- list(list(
    modules = list('logKow'),
    smiles = 'CCO',
    vaporPressureTemperatureC = 25
  ))
  original <- get('epi_submit_batch', namespace)
  before <- do.call(original, inputs)
  stopifnot(
    length(requests) == 1L,
    requests[[1L]]$url == 'https://ctx.example.test/submit/batch',
    identical(requests[[1L]]$body$data, expected_body[[1L]]),
    'x-api-key' %in% names(requests[[1L]]$headers)
  )

  mappings <- readRDS('evidence/interface-probe.rds')
  mapping <- mappings[['epi POST /api/submit/batch']]$settings
  mapping$request$arguments$body <- list(
    array = list(mapping$request$arguments$body)
  )
  mapping$request$arguments$server <- list(value = 'epi_burl')
  mapping$request$arguments$auth <- list(value = FALSE)
  callbacks <- new.env(parent = baseenv())
  sys.source(file.path(root, 'dev/apipak_callbacks.R'), callbacks)
  project <- apipak::load_project(root, callbacks = callbacks)
  service <- project$services$epi
  file <- tempfile(fileext = '.yml')
  on.exit(unlink(file), add = TRUE)
  yaml::write_yaml(mapping, file, precision = 17)
  service$operations[['POST /api/submit/batch']] <- getFromNamespace(
    'read_config_yaml',
    'apipak'
  )(file)
  operation <- apipak::read_operations(
    service$files,
    service$policy
  )$operations$epi_submit_batch
  configured <- getFromNamespace('configure_operation', 'apipak')(
    operation,
    service
  )
  context <- new.env(parent = namespace)
  eval(
    parse(
      text = apipak::render_operation(configured$operation, configured$spec)
    ),
    context
  )
  stopifnot(identical(formals(original), formals(context$epi_submit_batch)))
  after <- do.call(context$epi_submit_batch, inputs)
  stopifnot(
    length(requests) == 2L,
    requests[[2L]]$url == 'https://epi.example.test/api/submit/batch',
    requests[[2L]]$method == 'POST',
    identical(requests[[2L]]$body$data, expected_body),
    !'x-api-key' %in% names(requests[[2L]]$headers),
    identical(before, after),
    inherits(after, 'tbl_df'),
    nrow(after) == 1L
  )
  saveRDS(
    list(
      diagnosis = 'incorrect generated service, authentication and body mapping',
      expected_body = expected_body,
      settings = mapping,
      preserved = c(
        'formals',
        'default values',
        'helper response processing',
        'successful result'
      )
    ),
    'evidence/epi-batch-diagnosis.rds'
  )
  cat(
    'EPI batch: reproduced wrong service/auth/body; corrected declarative candidate preserves formals and successful return behavior. No network or client runtime changes.\n'
  )
  invisible(mapping)
}
if (sys.nframe() == 0L) {
  epi_batch_diagnosis(commandArgs(trailingOnly = TRUE)[[1L]])
}
