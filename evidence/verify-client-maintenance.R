verify_client_maintenance <- function(root) {
  withr::local_envvar(c(COMPTOXR_CRAN_SAFE_TESTS = 'true', NOT_CRAN = 'false', ctx_api_key = NA, GITHUB_OUTPUT = NA,
    TESTTHAT_PARALLEL = 'false', TESTTHAT_CPUS = '1'))
  devtools::test(root, filter = '^contract-|^chemi_resolver_ghs_list_count_bulk$|generate_tests_pipeline|stub_generation|diff_schemas|hooks|coverage_calc|remove_experimental', stop_on_failure = TRUE)
  cat('Adopted client fixed contracts, retained hook behavior and replacement maintenance integration passed.\n')
}
if (sys.nframe() == 0L) verify_client_maintenance(commandArgs(trailingOnly = TRUE)[[1L]])
