comptox_commands <- function(root) {
  stage <- readRDS('evidence/staged-client.rds')$root
  scripts <- c('generate_stubs.R', 'generate_tests.R', 'check_hook_config.R', 'check_public_api.R',
    'apipak-public.yml', 'apipak-readiness.yml', 'unit_test_readiness_audit.R', 'diff_schemas.R')
  stopifnot(all(file.copy(file.path(root, 'dev', scripts), file.path(stage, 'dev'), overwrite = TRUE)))
  output <- tempfile('comptox-commands-output-')
  on.exit(unlink(output), add = TRUE)
  withr::local_envvar(c(LC_ALL = 'C', COMPTOXR_CRAN_SAFE_TESTS = 'true', NOT_CRAN = 'false', ctx_api_key = NA, GITHUB_OUTPUT = output))
  withr::local_dir(tempdir())
  hashes <- function() tools::md5sum(list.files(stage, recursive = TRUE, full.names = TRUE, all.files = TRUE))
  before <- hashes()
  commands <- list(c('generate_stubs.R', '--check', '--rebuild=ct', '--rebuild=chemi', '--rebuild=epi'),
    c('generate_tests.R', '--check'), c('generate_stubs.R'), c('generate_tests.R', '--generate'),
    'check_hook_config.R', 'check_public_api.R')
  for (args in commands) {
    args[[1L]] <- file.path(stage, 'dev', args[[1L]])
    stopifnot(system2(file.path(R.home('bin'), 'Rscript'), shQuote(args)) == 0L)
  }
  stopifnot(identical(before, hashes()))
  values <- readLines(output)
  stopifnot(all(c('check_status=pass', 'gaps_remaining=0', 'stubs_generated=0',
    'tests_generated=0', 'drift_count=0') %in% values))
  cat('Staged client commands: all four required checks, unchanged generation, outside-root execution and CI output fields passed.\n')
  invisible(stage)
}
if (sys.nframe() == 0L) comptox_commands(commandArgs(trailingOnly = TRUE)[[1L]])
