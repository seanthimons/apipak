comptox_reports <- function(root) {
  stage <- readRDS('evidence/staged-client.rds')$root
  scripts <- c('calculate_coverage.R', 'apipak-coverage.yml', 'detect_test_gaps.R', 'apipak-testing.yml')
  stopifnot(all(file.copy(file.path(root, 'dev', scripts), file.path(stage, 'dev'), overwrite = TRUE)))
  context <- new.env(parent = globalenv())
  sys.source(file.path(root, 'dev/calculate_coverage.R'), context)
  sys.source(file.path(root, 'dev/detect_test_gaps.R'), context)
  before <- tools::md5sum(list.files(root, recursive = TRUE, all.files = TRUE, full.names = TRUE))
  current <- context$calculate_coverage(root, 'plan')
  baseline <- jsonlite::read_json(file.path(root, 'schema/coverage_baseline.json'))
  fields <- setdiff(names(baseline), 'timestamp')
  stopifnot(isTRUE(all.equal(current$baseline[fields], baseline[fields], check.attributes = FALSE)))
  candidate <- context$calculate_coverage(stage, 'plan')
  stopifnot(candidate$baseline$ccd_endpoints == 140L, candidate$baseline$chemi_endpoints == 191L,
    candidate$baseline$chemi_functions == 191L, candidate$baseline$epi_endpoints == 12L)
  gaps <- context$detect_gaps(stage, 'plan')
  if (gaps$gaps_count) print(gaps$gaps)
  stopifnot(gaps$gaps_count == 0L,
    identical(before, tools::md5sum(list.files(root, recursive = TRUE, all.files = TRUE, full.names = TRUE))))
  cat('Reports: unchanged baseline coverage, complete staged schema coverage, zero selected/manual test gaps and read-only plans passed.\n')
}
if (sys.nframe() == 0L) comptox_reports(commandArgs(trailingOnly = TRUE)[[1L]])
