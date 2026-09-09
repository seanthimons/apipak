maintenance_cli <- function(root) {
  root <- normalizePath(root, winslash = '/', mustWork = TRUE)
  withr::local_envvar(c(LC_ALL = 'C', COMPTOXR_CRAN_SAFE_TESTS = 'true', NOT_CRAN = 'false', ctx_api_key = NA, GITHUB_OUTPUT = NA))
  files <- list.files(root, recursive = TRUE, full.names = TRUE, all.files = TRUE)
  files <- files[!dir.exists(files)]
  before <- tools::md5sum(files)
  withr::local_dir(tempdir())
  for (script in c('check_public_api.R', 'check_hook_config.R')) {
    status <- system2(file.path(R.home('bin'), 'Rscript'), shQuote(file.path(root, 'dev', script)))
    stopifnot(status == 0L)
  }
  stopifnot(identical(before, tools::md5sum(files)))
  devtools::test(root, filter = 'hooks', stop_on_failure = TRUE)
  cat('Maintenance commands pass from outside the client root without changing files; existing hook tests pass.\n')
}
if (sys.nframe() == 0L) maintenance_cli(commandArgs(trailingOnly = TRUE)[[1L]])
