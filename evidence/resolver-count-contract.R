resolver_count_contract <- function(root) {
  root <- normalizePath(root, winslash = '/', mustWork = TRUE)
  withr::local_envvar(c(
    COMPTOXR_CRAN_SAFE_TESTS = 'true',
    NOT_CRAN = 'false',
    ctx_api_key = NA,
    GITHUB_OUTPUT = NA
  ))
  pkgload::load_all(root, quiet = TRUE)
  withr::local_options(list(
    ComptoxR.run_debug = FALSE,
    ComptoxR.run_verbose = FALSE
  ))
  callbacks <- new.env(parent = baseenv())
  sys.source(file.path(root, 'dev/apipak_callbacks.R'), callbacks)
  service <- apipak::load_project(root, callbacks = callbacks)$services[[
    'chemi-resolver'
  ]]
  parsed <- getFromNamespace('read_service_operations', 'apipak')(service)
  op <- parsed$operations$chemi_resolver_ghs_list_count_bulk
  stopifnot(
    op$method == 'POST',
    op$path == '/api/resolver/ghs-list-count',
    op$body$type == 'object',
    op$body$additionalProperties$type == 'array',
    op$body$additionalProperties$items$type == 'array',
    op$body$additionalProperties$items$items$type == 'string'
  )
  configured <- getFromNamespace('configure_operation', 'apipak')(op, service)
  env <- new.env(parent = asNamespace('ComptoxR'))
  eval(
    parse(
      text = apipak::render_operation(configured$operation, configured$spec)
    ),
    env
  )
  testthat::local_mocked_bindings(
    .endpoint_url = function(server) {
      stopifnot(server == 'chemi_burl')
      'https://chemi.example.test/api'
    },
    .package = 'ComptoxR'
  )
  captured <- list()
  testthat::local_mocked_bindings(
    req_perform = function(req, ...) {
      captured[[length(captured) + 1L]] <<- req
      httr2::response(
        status_code = 200,
        headers = list(`Content-Type` = 'application/json'),
        body = charToRaw('[{"hcode":"H301","count":2}]')
      )
    },
    .package = 'httr2'
  )
  expected <- list(list(hcode = 'H301', count = 2L))
  stopifnot(identical(env$chemi_resolver_ghs_list_count_bulk(), expected))
  body <- list(fixture = list(list('first', 'second')))
  stopifnot(
    identical(env$chemi_resolver_ghs_list_count_bulk(body), expected),
    length(captured) == 2L,
    identical(captured[[1L]]$body$data, stats::setNames(list(), character())),
    identical(captured[[2L]]$body$data, body)
  )
  for (request in captured) {
    stopifnot(
      request$method == 'POST',
      request$url == 'https://chemi.example.test/api/resolver/ghs-list-count',
      !'x-api-key' %in% names(request$headers)
    )
  }
  error <- tryCatch(
    env$chemi_resolver_ghs_list_count_bulk(NULL),
    error = identity
  )
  stopifnot(inherits(error, 'error'), length(captured) == 2L)
  contract <- service$contracts$chemi_resolver_ghs_list_count_bulk
  stopifnot(
    identical(contract$result, expected),
    identical(contract$response_fixture, expected)
  )
  text <- getFromNamespace('render_contract', 'apipak')(
    configured$operation,
    configured$spec,
    contract
  )
  stopifnot(length(parse(text = text)) == 1L, grepl('H301', text, fixed = TRUE))
  cat(
    'Public resolver POST candidate: exact URL/method/auth/JSON shape, default and nested body, successful counts and NULL rejection passed through the unchanged HTTP helper.\n'
  )
  invisible(configured)
}
if (sys.nframe() == 0L) {
  resolver_count_contract(commandArgs(trailingOnly = TRUE)[[1L]])
}
