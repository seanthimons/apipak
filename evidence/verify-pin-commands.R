verify_pin_commands <- function(root) {
  root <- normalizePath(root, winslash = '/', mustWork = TRUE)
  pin <- jsonlite::read_json(file.path(root, 'dev/toolkit-lock.json'))
  stopifnot(as.character(packageVersion(pin$package)) == pin$version)
  hashes <- function() tools::md5sum(list.files(root, recursive = TRUE, all.files = TRUE, full.names = TRUE))
  before <- hashes()
  withr::local_envvar(c(COMPTOXR_CRAN_SAFE_TESTS = 'true', NOT_CRAN = 'false', ctx_api_key = NA, GITHUB_OUTPUT = NA))
  withr::local_dir(tempdir())
  commands <- list('generate_stubs.R' = c('--check', '--rebuild=ct', '--rebuild=chemi', '--rebuild=epi'),
    'generate_tests.R' = '--check', 'check_hook_config.R' = character(), 'check_public_api.R' = character())
  for (script in names(commands)) stopifnot(system2(file.path(R.home('bin'), 'Rscript'),
    c(shQuote(file.path(root, 'dev', script)), commands[[script]])) == 0L)
  stopifnot(identical(before, hashes()))
  cat('Verified release pin:', pin$version, find.package(pin$package), '; all four outside-root commands passed read-only.\n')
}
if (sys.nframe() == 0L) verify_pin_commands(commandArgs(trailingOnly = TRUE)[[1L]])
