# Source this file and call production_baseline(root, output) interactively.
production_baseline <- function(root, output) {
  root <- normalizePath(root, winslash = '/', mustWork = TRUE)
  dir.create(output, recursive = TRUE, showWarnings = FALSE)
  output <- normalizePath(output, winslash = '/', mustWork = TRUE)
  previous <- setwd(root)
  on.exit(setwd(previous), add = TRUE)
  Sys.setenv(COMPTOXR_CRAN_SAFE_TESTS = 'true', NOT_CRAN = 'false', LC_ALL = 'C')
  Sys.unsetenv(c('ctx_api_key', 'GITHUB_OUTPUT'))
  baseline_lib <- file.path(output, 'library')
  dir.create(baseline_lib, showWarnings = FALSE)
  .libPaths(c(baseline_lib, .libPaths()))
  Sys.setenv(R_LIBS = paste(.libPaths(), collapse = .Platform$path.sep))
  tracked <- system2('git', c('ls-files'), stdout = TRUE)
  hashes <- vapply(tracked, function(path) digest::digest(file = path, algo = 'sha256'), character(1))
  jsonlite::write_json(as.list(hashes), file.path(output, 'tracked-sha256.json'), pretty = TRUE, auto_unbox = TRUE)
  writeLines(c(system2('git', c('rev-parse', 'HEAD'), stdout = TRUE), capture.output(sessionInfo())), file.path(output, 'environment.txt'))
  source('dev/install_toolkit.R', local = TRUE)
  install_toolkit(lib = baseline_lib)
  writeLines(c(find.package('wrapmaint'), as.character(packageVersion('wrapmaint'))), file.path(output, 'installed.txt'))
  tests <- tryCatch({
    devtools::test(filter = 'generate_tests_pipeline|stub_generation|diff_schemas|hooks', stop_on_failure = TRUE)
    TRUE
  }, error = function(e) {
    message(conditionMessage(e))
    FALSE
  })
  commands <- list(
    stubs = c('dev/generate_stubs.R', '--check', '--rebuild=ct', '--rebuild=chemi', '--rebuild=epi'),
    tests = c('dev/generate_tests.R', '--check'),
    hooks = 'dev/check_hook_config.R',
    public_api = 'dev/check_public_api.R'
  )
  statuses <- vapply(names(commands), function(name) {
    system2(file.path(R.home('bin'), 'Rscript'), commands[[name]],
      stdout = file.path(output, paste0(name, '.log')), stderr = file.path(output, paste0(name, '.log')))
  }, integer(1))
  after <- vapply(tracked, function(path) digest::digest(file = path, algo = 'sha256'), character(1))
  result <- list(tests_passed = tests, cli_status = as.list(statuses), unchanged = identical(hashes, after))
  jsonlite::write_json(result, file.path(output, 'results.json'), pretty = TRUE, auto_unbox = TRUE)
  print(result)
  invisible(result)
}

if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  result <- production_baseline(args[[1L]], args[[2L]])
  if (!result$tests_passed || any(unlist(result$cli_status) != 0L) || !result$unchanged) quit(status = 1L)
}
