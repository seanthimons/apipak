# Archive/package checks complement the separately executed offline contracts.
check_client_package <- function(root) {
  output <- file.path(normalizePath('evidence', winslash = '/', mustWork = TRUE), 'client-package')
  dir.create(output, showWarnings = FALSE)
  withr::local_envvar(c(COMPTOXR_CRAN_SAFE_TESTS = 'true', NOT_CRAN = 'false',
    ctx_api_key = NA, '_R_CHECK_FORCE_SUGGESTS_' = 'false'))
  archive <- pkgbuild::build(root, dest_path = output, vignettes = FALSE, manual = FALSE)
  result <- rcmdcheck::rcmdcheck(archive, args = c('--no-manual', '--no-tests', '--no-examples', '--ignore-vignettes'),
    error_on = 'never', check_dir = file.path(output, 'check'))
  jsonlite::write_json(list(errors = result$errors, warnings = result$warnings, notes = result$notes),
    'evidence/client-package-check.json', pretty = TRUE, auto_unbox = TRUE)
  stopifnot(!length(result$errors))
  invisible(result)
}
if (sys.nframe() == 0L) check_client_package(commandArgs(trailingOnly = TRUE)[[1L]])
