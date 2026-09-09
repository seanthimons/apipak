retire_client_pipeline <- function(root, apply = FALSE) {
  root <- normalizePath(root, winslash = '/', mustWork = TRUE)
  baseline <- jsonlite::read_json('evidence/baseline/tracked-sha256.json')
  replacements <- list(
    'dev/toolkit_adapter.R' = r"---(# Client inspection from the same explicit inputs as generation.
.toolkit_root <- apipak::script_root('toolkit_adapter.R')
comptox_inventory <- function(root = .toolkit_root) {
  callbacks <- new.env(parent = baseenv())
  sys.source(file.path(root, 'dev/apipak_callbacks.R'), envir = callbacks)
  apipak::inspect_client(root, callbacks = callbacks)
}
)---",
    'tests/testthat/test-generate_tests_pipeline.R' = r"---(root <- normalizePath(testthat::test_path('..', '..'), winslash = '/')
script <- file.path(root, 'dev/generate_tests.R')
if (!file.exists(script)) testthat::skip('Maintainer-only generation command is excluded from source archives')
source(script, local = TRUE)
source(file.path(root, 'dev/token_preflight.R'), local = TRUE)

test_that('selected fixed contracts are current and report successful CI fields', {
  output <- withr::local_tempfile()
  withr::local_envvar(c(GITHUB_OUTPUT = output))
  expect_no_error(generate_tests_main('--check', root))
  expect_true(all(c('check_status=pass', 'gaps_remaining=0', 'tests_generated=0') %in% readLines(output)))
})

test_that('recording token preflight still rejects placeholders without logging values', {
  for (value in c('', 'dummy_ctx_key', '<<<API_KEY>>>', 'xxxxxxxx')) {
    expect_false(ctx_api_key_status(value)$valid)
  }
  expect_true(ctx_api_key_status('realistic-token-value-123')$valid)
  error <- rlang::catch_cnd(ctx_api_key_preflight('dummy-do-not-log'))
  expect_s3_class(error, 'error')
  expect_false(grepl('dummy-do-not-log', conditionMessage(error), fixed = TRUE))
})
)---",
    'tests/testthat/test-stub_generation_call_shape.R' = r"---(root <- normalizePath(testthat::test_path('..', '..'), winslash = '/')
script <- file.path(root, 'dev/check_hook_config.R')
if (!file.exists(script)) testthat::skip('Maintainer-only hook command is excluded from source archives')
source(script, local = TRUE)

test_that('generated wrappers retain the configured hook stages and request fields', {
  result <- check_hook_config(root)
  expect_true(result$valid)
  expect_gt(result$hooks, 0)
  expect_gt(result$parameters, 0)
})
)---",
    'tests/testthat/test-stub_generation_multischema.R' = r"---(root <- normalizePath(testthat::test_path('..', '..'), winslash = '/')
script <- file.path(root, 'dev/toolkit_adapter.R')
if (!file.exists(script)) testthat::skip('Maintainer-only schema policy is excluded from source archives')
source(script, local = TRUE)
source(file.path(root, 'dev/check_public_api.R'), local = TRUE)

test_that('all selected public operations have exported implementations and fixed contracts', {
  inventory <- comptox_inventory(root)
  expect_true(all(vapply(inventory$operations, `[[`, logical(1), 'implemented')))
  expect_true(all(vapply(inventory$operations, `[[`, logical(1), 'contract_declared')))
  expect_true(all(vapply(inventory$operations, function(x) !is.null(x$contract_file), logical(1))))
  expect_true(all(vapply(inventory$inventory, function(x) x$status %in% c('selected', 'excluded', 'client-mapped', 'retained-unsupported'), logical(1))))
  expect_true(check_public_api(root))
})
)---",
    'tests/testthat/test-coverage_calc.R' = r"---(root <- normalizePath(testthat::test_path('..', '..'), winslash = '/')
script <- file.path(root, 'dev/calculate_coverage.R')
if (!file.exists(script)) testthat::skip('Maintainer-only coverage command is excluded from source archives')
source(script, local = TRUE)
source(file.path(root, 'dev/toolkit_adapter.R'), local = TRUE)

test_that('coverage uses selected operations and excludes manual exports from its denominator', {
  inventory <- comptox_inventory(root)
  totals <- vapply(inventory$coverage, `[[`, integer(1), 'total')
  implemented <- vapply(inventory$coverage, `[[`, integer(1), 'implemented')
  expect_equal(implemented, totals)
  expect_equal(sum(totals), length(inventory$operations))
  expect_gt(length(inventory$manual_exports), 0)
  report <- calculate_coverage(root, 'plan')
  expect_true(all(c('ccd_endpoints', 'chemi_endpoints', 'epi_endpoints') %in% names(report$baseline)))
  expect_equal(sum(unlist(report$baseline[grep('_endpoints$', names(report$baseline))])), sum(totals))
})
)---"
  )
  remove <- c(unlist(lapply(c('endpoint_eval', 'test_generation'), function(directory) {
    paste0('dev/', directory, '/', list.files(file.path(root, 'dev', directory), '\\.R$'))
  }), use.names = FALSE),
    'dev/endpoint_eval_utils.R', 'dev/stub_specs.R', 'dev/ct_endpoint_eval.R',
    'dev/chemi_endpoint_eval.R', 'dev/cc_endpoint_eval.R', 'dev/remove_experimental.R',
    'tests/testthat/helper-pipeline.R')
  files <- c(names(replacements), remove)
  for (file in files) {
    path <- file.path(root, file)
    stopifnot(!is.null(baseline[[file]]),
      identical(digest::digest(file = path, algo = 'sha256'), baseline[[file]]))
  }
  for (text in replacements) parse(text = text)
  plan <- list(replace = names(replacements), remove = remove,
    validation = c('toolkit installed acceptance', 'all per-operation fixed contracts',
      'client command/hook/public/coverage integration', 'recording token preflight'))
  jsonlite::write_json(plan, 'evidence/pipeline-retirement.json', pretty = TRUE, auto_unbox = TRUE)
  if (apply) {
    for (file in names(replacements)) writeLines(replacements[[file]], file.path(root, file))
    stopifnot(unlink(file.path(root, remove), recursive = FALSE) == 0L)
  }
  cat(length(remove), 'reviewed legacy files retire; five adapters/integration tests replace implementation-specific callers.\n')
  invisible(plan)
}
if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  retire_client_pipeline(args[[1L]], '--apply' %in% args)
}
