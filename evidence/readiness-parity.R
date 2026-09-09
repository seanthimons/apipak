readiness_parity <- function(root) {
  context <- new.env(parent = baseenv())
  sys.source(file.path(root, 'dev/unit_test_readiness_audit.R'), context)
  before <- readRDS('evidence/baseline/readiness.rds')
  after <- context$build_unit_test_readiness_audit(root)
  before$metadata$generated_at_utc <- NULL
  after$metadata$generated_at_utc <- NULL
  encode <- function(x) as.character(jsonlite::toJSON(x, auto_unbox = TRUE, null = 'null', digits = NA))
  if (!identical(encode(before), encode(after))) {
    print(all.equal(before, after))
    stop('Readiness artifact differs from the frozen baseline')
  }
  testthat::test_file(file.path(root, 'tests/testthat/test-unit_test_readiness_audit.R'), stop_on_failure = TRUE)
  cat('Readiness: frozen artifact parity and existing targeted tests passed.\n')
  invisible(after)
}
if (sys.nframe() == 0L) readiness_parity(commandArgs(trailingOnly = TRUE)[[1L]])
