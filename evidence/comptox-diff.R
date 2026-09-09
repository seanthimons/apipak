comptox_diff <- function(root) {
  context <- new.env(parent = globalenv())
  sys.source(file.path(root, 'dev/diff_schemas.R'), context)
  schema <- file.path(root, 'schema')
  result <- context$diff_schemas(schema, schema, '-prod[.]json$', 'prod', 'ui|coverage_baseline|schema_hashes')
  stopifnot(!length(result))
  testthat::test_file(file.path(root, 'tests/testthat/test-diff_schemas_counts.R'), stop_on_failure = TRUE)
  cat('Client schema diff: unchanged public snapshots and existing report/count/new-domain checks passed.\n')
}
if (sys.nframe() == 0L) comptox_diff(commandArgs(trailingOnly = TRUE)[[1L]])
