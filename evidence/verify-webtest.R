verify_webtest <- function(root) {
  withr::local_envvar(c(COMPTOXR_CRAN_SAFE_TESTS = 'true', NOT_CRAN = 'false', ctx_api_key = NA, GITHUB_OUTPUT = NA))
  devtools::test(root, filter = '^hooks-webtest$', stop_on_failure = TRUE)
}
if (sys.nframe() == 0L) verify_webtest(commandArgs(trailingOnly = TRUE)[[1L]])
