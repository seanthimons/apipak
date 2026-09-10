# Verify the installed client and fixed contracts with both toolkits unavailable.
verify_client_runtime <- function(root) {
  root <- normalizePath(root, winslash = '/', mustWork = TRUE)
  library <- normalizePath('evidence', winslash = '/', mustWork = TRUE)
  library <- file.path(library, 'client-runtime-library')
  dir.create(library, showWarnings = FALSE)
  fields <- read.dcf(file.path(root, 'DESCRIPTION'))
  packages <- c('testthat', 'httr2', trimws(sub(' *\\(.*', '', strsplit(fields[[1L, 'Imports']], ',')[[1L]])))
  packages <- unique(c(packages, unlist(tools::package_dependencies(packages, installed.packages(),
    which = c('Depends', 'Imports', 'LinkingTo'), recursive = TRUE))))
  for (package in setdiff(packages, c('R', 'specmill', 'wrapmaint'))) {
    source <- find.package(package)
    if (!startsWith(normalizePath(source, winslash = '/'), normalizePath(.Library, winslash = '/')) &&
        !dir.exists(file.path(library, package))) stopifnot(file.copy(source, library, recursive = TRUE))
  }
  status <- system2(file.path(R.home('bin'), if (.Platform$OS.type == 'windows') 'R.exe' else 'R'),
    c('CMD', 'INSTALL', paste0('--library=', shQuote(library)), shQuote(root)))
  stopifnot(status == 0L)
  libraries <- .libPaths()[!file.exists(file.path(.libPaths(), 'specmill')) & !file.exists(file.path(.libPaths(), 'wrapmaint'))]
  callr::r(function(root) {
    stopifnot(!requireNamespace('specmill', quietly = TRUE), !requireNamespace('wrapmaint', quietly = TRUE))
    dependencies <- tools::package_dependencies('ComptoxR', installed.packages(), recursive = TRUE)[[1L]]
    for (package in setdiff(dependencies, 'R')) requireNamespace(package, quietly = TRUE)
    requireNamespace('testthat', quietly = TRUE)
    requireNamespace('httr2', quietly = TRUE)
    testthat::local_mocked_bindings(req_perform = function(...) stop('Unexpected load-time HTTP'), .package = 'httr2')
    options_before <- options()
    requireNamespace('ComptoxR', quietly = TRUE)
    stopifnot(identical(options_before, options()))
    library(ComptoxR)
    tests <- c(list.files(file.path(root, 'tests/testthat'), '^test-contract-.*\\.R$', full.names = TRUE),
      file.path(root, 'tests/testthat/test-chemi_resolver_ghs_list_count_bulk.R'))
    stopifnot(length(tests) == 343L)
    env <- new.env(parent = globalenv())
    for (test in tests) testthat::test_file(test, env = env, reporter = 'silent',
      load_helpers = FALSE, stop_on_failure = TRUE)
    stopifnot(!any(c('specmill', 'wrapmaint') %in% loadedNamespaces()))
    cat('Installed ComptoxR: 343 fixed contracts; no toolkit, load-time HTTP or option mutation.\n')
  }, args = list(root), libpath = c(library, libraries), show = TRUE)
}
if (sys.nframe() == 0L) verify_client_runtime(commandArgs(trailingOnly = TRUE)[[1L]])
