extract_readiness_policy <- function(root) {
  original <- new.env(parent = baseenv())
  sys.source(file.path(root, 'dev/unit_test_readiness_audit.R'), original)
  report_call <- tail(as.list(body(original$build_unit_test_readiness_audit)), 1L)[[1L]]
  fields <- as.list(report_call)
  policy <- list(
    credential_name = 'ctx_api_key',
    credential_pattern = 'ctx_api_key\\s*:.*secrets\\.|CTX_API_KEY|COMPTOX_API_KEY',
    issue = eval(as.list(fields$metadata)$issue, baseenv()),
    vcr_issue = original$read_vcr_test_classification(tempfile())$issue,
    badge_files = list(ccd = '.github/badges/ccd-coverage.json', chemi = '.github/badges/chemi-coverage.json'),
    coverage_files = c('codecov.yml', 'schema/coverage_baseline.json', '.github/badges/ccd-coverage.json', '.github/badges/chemi-coverage.json'),
    testing_docs = c('.planning/codebase/TESTING.md', 'dev/TESTING_GUIDE.md'),
    test_tiers = original$audit_test_tiers(),
    cran_readiness_criteria = eval(fields$cran_readiness_criteria, baseenv())
  )
  destination <- file.path(root, 'dev/apipak-readiness.yml')
  stopifnot(!file.exists(destination))
  yaml::write_yaml(policy, destination)
  saveRDS(original$build_unit_test_readiness_audit(root), 'evidence/baseline/readiness.rds')
  expressions <- as.list(parse('R/readiness.R', keep.source = FALSE))
  names <- vapply(expressions, function(x) {
    stopifnot(is.call(x), identical(x[[1L]], as.name('<-')), is.symbol(x[[2L]]))
    as.character(x[[2L]])
  }, character(1))
  cat('\ntool_groups$readiness <- ', paste(deparse(names, width.cutoff = 100L), collapse = '\n'), '\n',
    file = 'R/readiness.R', append = TRUE, sep = '')
  cat(length(names), 'readiness bindings extracted with client policy and baseline report.\n')
}
if (sys.nframe() == 0L) extract_readiness_policy(commandArgs(trailingOnly = TRUE)[[1L]])
