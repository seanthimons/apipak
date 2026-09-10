readiness_acceptance <- function() {
  root <- tempfile('readiness-client-')
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  put <- function(path, lines) {
    path <- file.path(root, path)
    dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
    writeLines(lines, path)
  }
  put('DESCRIPTION', c('Package: auditfixture', 'Version: 0.0.1'))
  put('R/alpha.R', 'alpha <- function() 1')
  put('NAMESPACE', 'export(alpha)')
  put(
    'tests/testthat/test-alpha.R',
    "test_that('demo_token is offline', { expect_identical(alpha(), 1) })"
  )
  put(
    'dev/policy.yml',
    c(
      'credential_name: demo_token',
      'credential_pattern: demo_token',
      'vcr_issue: {github_issue: 42, bean: demo-42, title: Fixture classification}',
      'test_tiers: {unit: {label: Unit, requirements: [Offline], activation: [Tests]}}'
    )
  )
  context <- new.env(parent = asNamespace('specmill'))
  specmill::bind_tools('readiness', context)
  context$audit_policy <- context$read_audit_policy(file.path(
    root,
    'dev/policy.yml'
  ))
  files <- list.files(root, recursive = TRUE, full.names = TRUE)
  before <- tools::md5sum(files)
  report <- context$build_unit_test_readiness_audit(root)
  stopifnot(
    identical(before, tools::md5sum(files)),
    !length(report$comparisons$exports_vs_tests$export_gaps),
    report$comparisons$vcr_classification$valid,
    identical(report$test_tiers$unit$requirements, 'Offline')
  )
  second <- new.env(parent = asNamespace('specmill'))
  specmill::bind_tools('readiness', second)
  stopifnot(!length(second$audit_policy), length(context$audit_policy) > 0L)
  put('NAMESPACE', c('export(alpha)', 'export(beta)'))
  put('R/beta.R', 'beta <- function() 2')
  error <- tryCatch(
    context$unit_test_readiness_audit_main('--fail-on-gaps', root),
    error = identity
  )
  stopifnot(
    inherits(error, 'error'),
    grepl('Export test gaps', conditionMessage(error))
  )
  put('dev/audit.R', "located_root <- specmill::script_root('audit.R')")
  sourced <- new.env(parent = baseenv())
  sys.source(file.path(root, 'dev/audit.R'), sourced)
  stopifnot(identical(
    sourced$located_root,
    normalizePath(root, winslash = '/')
  ))
  cat(
    'Readiness: client policy, isolated contexts, read-only inventory, blocking gaps and source-root discovery passed.\n'
  )
}
if (sys.nframe() == 0L) {
  readiness_acceptance()
}
