comptox_pilot <- function(root) {
  root <- normalizePath(root, winslash = '/', mustWork = TRUE)
  Sys.setenv(COMPTOXR_CRAN_SAFE_TESTS = 'true', NOT_CRAN = 'false')
  Sys.unsetenv(c('ctx_api_key', 'GITHUB_OUTPUT'))
  pkgload::load_all(root, quiet = TRUE)
  project <- apipak::load_project(root, 'dev/apipak-pilot.yml')
  service <- project$services$ctx
  parsed <- apipak::read_operations(service$files, service$policy)
  stopifnot(length(parsed$operations) == 1L, !length(parsed$diagnostics))
  configured <- getFromNamespace('configure_operation', 'apipak')(
    parsed$operations[[1L]],
    service
  )
  code <- apipak::render_operation(configured$operation, configured$spec)
  context <- new.env(parent = asNamespace('ComptoxR'))
  eval(parse(text = code), context)
  candidate <- context$ct_chemical_list_all
  stopifnot(identical(
    formals(candidate),
    formals(ComptoxR::ct_chemical_list_all)
  ))
  fixture <- tibble::tibble(
    listName = c('LIST_A', 'LIST_B'),
    dtxsids = c('DTXSID1,DTXSID2', 'DTXSID3')
  )
  captured <- list()
  testthat::local_mocked_bindings(
    generic_request = function(...) {
      captured[[length(captured) + 1L]] <<- list(...)
      fixture
    },
    .package = 'ComptoxR'
  )
  for (inputs in list(
    list(),
    list(projection = 'chemicallistname'),
    list(return_dtxsid = TRUE),
    list(return_dtxsid = TRUE, coerce = TRUE)
  )) {
    captured <- list()
    before <- suppressMessages(do.call(ComptoxR::ct_chemical_list_all, inputs))
    expected_request <- captured
    captured <- list()
    after <- suppressMessages(do.call(candidate, inputs))
    stopifnot(
      identical(after, before),
      identical(captured, expected_request),
      length(captured) == 1L
    )
    stopifnot(
      identical(captured[[1L]]$endpoint, 'chemical/list/all'),
      identical(captured[[1L]]$method, 'GET'),
      identical(captured[[1L]]$batch_limit, 0)
    )
  }
  testthat::test_file(
    file.path(root, 'tests/testthat/test-ct_chemical_list_all_hooks.R'),
    stop_on_failure = TRUE
  )
  stage <- tempfile('comptox-pilot-')
  dir.create(stage)
  on.exit(unlink(stage, recursive = TRUE), add = TRUE)
  inputs <- intersect(
    c(
      'R',
      'man',
      'inst',
      'data',
      'DESCRIPTION',
      'NAMESPACE',
      'LICENSE',
      'apis',
      'schema'
    ),
    list.files(root)
  )
  stopifnot(all(file.copy(file.path(root, inputs), stage, recursive = TRUE)))
  dir.create(file.path(stage, 'dev'))
  file.copy(
    file.path(root, 'dev/apipak-pilot.yml'),
    file.path(stage, 'dev/apipak-pilot.yml')
  )
  unlink(file.path(
    stage,
    c('R/ct_chemical_list_all.R', 'man/ct_chemical_list_all.Rd')
  ))
  hashes <- function() {
    tools::md5sum(list.files(
      stage,
      recursive = TRUE,
      full.names = TRUE,
      all.files = TRUE
    ))
  }
  before <- hashes()
  plan <- apipak::generate_client(
    stage,
    config = 'dev/apipak-pilot.yml',
    mode = 'plan'
  )
  stopifnot(identical(before, hashes()))
  actions <- vapply(plan$files, `[[`, character(1), 'action')
  if (any(actions == 'protected')) {
    stop(
      'Pilot protected outputs: ',
      paste(
        vapply(plan$files[actions == 'protected'], `[[`, character(1), 'file'),
        collapse = ', '
      )
    )
  }
  apipak::generate_client(
    stage,
    config = 'dev/apipak-pilot.yml',
    mode = 'apply'
  )
  file.copy(
    file.path(stage, 'man/ct_chemical_list_all.Rd'),
    'evidence/current-pilot.Rd',
    overwrite = TRUE
  )
  # Roxygen formatting may differ, but all Rd tokens, examples and exports must agree.
  rd <- function(path) {
    tools::parse_Rd(path, fragment = FALSE, encoding = 'UTF-8')
  }
  normalize_rd <- function(x) {
    attributes(x) <- attributes(x)[intersect(
      names(attributes(x)),
      c('Rd_tag', 'Rd_option')
    )]
    if (is.list(x)) {
      x <- lapply(x, normalize_rd)
    }
    if (is.character(x)) {
      x <- gsub('[[:space:]]+', ' ', x)
    }
    x
  }
  stopifnot(identical(
    normalize_rd(rd(file.path(root, 'man/ct_chemical_list_all.Rd'))),
    normalize_rd(rd(file.path(stage, 'man/ct_chemical_list_all.Rd')))
  ))
  after <- hashes()
  apipak::generate_client(
    stage,
    config = 'dev/apipak-pilot.yml',
    mode = 'check'
  )
  apipak::generate_client(
    stage,
    config = 'dev/apipak-pilot.yml',
    mode = 'apply'
  )
  stopifnot(identical(after, hashes()))
  testthat::local_mocked_bindings(
    ct_chemical_list_all = candidate,
    .package = 'ComptoxR'
  )
  testthat::test_file(
    file.path(stage, 'tests/testthat/test-ct_chemical_list_all.R'),
    stop_on_failure = TRUE
  )
  cat(
    'ComptoxR pilot: typed YAML preserves formals, defaults, exact requests, successful values and retained hooks for ct_chemical_list_all.\n'
  )
  invisible(code)
}
if (sys.nframe() == 0L) {
  comptox_pilot(commandArgs(trailingOnly = TRUE)[[1L]])
}
