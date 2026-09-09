# Reconcile already-adopted output, then verify all production commands read-only.
final_client_generation <- function(root) {
  root <- normalizePath(root, winslash = '/', mustWork = TRUE)
  pin <- jsonlite::read_json(file.path(root, 'dev/toolkit-lock.json'))
  stopifnot(pin$package == 'apipak', as.character(packageVersion('apipak')) == pin$version)
  cat('Verified installed pin:', pin$version, find.package('apipak'), '\n')
  callbacks <- new.env(parent = baseenv())
  sys.source(file.path(root, 'dev/apipak_callbacks.R'), callbacks)
  apipak::generate_client(root, config = 'apipak.yml', callbacks = callbacks, mode = 'apply')
  hashes <- function() tools::md5sum(list.files(root, recursive = TRUE, all.files = TRUE, full.names = TRUE))
  before <- hashes()
  apipak::generate_client(root, config = 'apipak.yml', callbacks = callbacks, mode = 'check')
  apipak::generate_client(root, config = 'apipak.yml', callbacks = callbacks, mode = 'apply')
  withr::local_envvar(c(COMPTOXR_CRAN_SAFE_TESTS = 'true', NOT_CRAN = 'false', ctx_api_key = NA, GITHUB_OUTPUT = NA))
  withr::local_dir(tempdir())
  commands <- list('generate_stubs.R' = c('--check', '--rebuild=ct', '--rebuild=chemi', '--rebuild=epi'),
    'generate_tests.R' = '--check', 'check_hook_config.R' = character(), 'check_public_api.R' = character())
  for (script in names(commands)) {
    status <- system2(file.path(R.home('bin'), 'Rscript'), c(shQuote(file.path(root, 'dev', script)), commands[[script]]))
    stopifnot(status == 0L)
  }
  stopifnot(identical(before, hashes()))
  cat('Final generation, four outside-root commands and second apply passed without changes.\n')
}
if (sys.nframe() == 0L) final_client_generation(commandArgs(trailingOnly = TRUE)[[1L]])
