commands_acceptance <- function() {
  root <- tempfile('command-client-')
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  fixture <- system.file('catalogue', package = 'apipak', mustWork = TRUE)
  stopifnot(all(file.copy(
    list.files(fixture, full.names = TRUE),
    root,
    recursive = TRUE
  )))
  writeLines(
    c('config_version: 1', 'services: [catalogue.yml]'),
    file.path(root, 'apipak.yml')
  )
  service <- c(
    'id: catalogue',
    'schemas: {files: [schema.json]}',
    'helper: catalogue_request',
    'selection: {methods: [POST], exclude: ["^/items"]}',
    'contracts_file: tests/testthat/fixtures/fixed.rds'
  )
  writeLines(service, file.path(root, 'catalogue.yml'))
  dir.create(file.path(root, 'tests/testthat/fixtures'), recursive = TRUE)
  saveRDS(
    list(
      refresh = list(
        inputs = list(),
        calls = list(list(
          helper = 'catalogue_request',
          arguments = list(
            method = 'POST',
            path = '/refresh',
            path_params = list(),
            query = list(),
            body = NULL
          ),
          response = list(data = 'ok')
        )),
        result = list(data = 'ok')
      )
    ),
    file.path(root, 'tests/testthat/fixtures/fixed.rds')
  )
  output <- tempfile('command-output-')
  on.exit(unlink(output), add = TRUE)
  withr::local_envvar(c(GITHUB_OUTPUT = output))
  hashes <- function() {
    tools::md5sum(list.files(
      root,
      recursive = TRUE,
      full.names = TRUE,
      all.files = TRUE
    ))
  }
  before <- hashes()
  apipak::generation_command(root, '--plan')
  apipak::generation_command(root, '--dry-run', 'tests')
  stopifnot(
    identical(before, hashes()),
    'check_status=dry_run' %in% readLines(output)
  )
  apipak::generation_command(root)
  stopifnot(
    !file.exists(file.path(root, 'tests/testthat/test-contract-refresh.R'))
  )
  runtime <- tools::md5sum(file.path(root, 'R/refresh.R'))
  apipak::generation_command(root, '--generate', 'tests')
  stopifnot(
    identical(runtime, tools::md5sum(file.path(root, 'R/refresh.R'))),
    'tests_created=1' %in% readLines(output),
    'stubs_created=1' %in% readLines(output)
  )
  before <- hashes()
  for (kind in c('stubs', 'tests')) {
    apipak::generation_command(root, '--check', kind)
    apipak::generation_command(root, character(), kind)
  }
  stopifnot(identical(before, hashes()))
  fails <- function(expression, pattern) {
    error <- tryCatch(force(expression), error = identity)
    stopifnot(inherits(error, 'error'), grepl(pattern, conditionMessage(error)))
  }
  policy <- list(
    baseline = 'coverage.json',
    groups = list(
      sample = list(
        services = '^catalogue$',
        label = 'Sample coverage',
        badge = 'badge.json'
      )
    )
  )
  coverage <- apipak::coverage_report(root, policy)
  stopifnot(
    identical(before, hashes()),
    coverage$baseline$sample_endpoints == 1L,
    coverage$baseline$sample_functions == 1L,
    coverage$outputs$sample_coverage == '100.0'
  )
  apipak::coverage_report(root, policy, mode = 'apply')
  stopifnot(
    jsonlite::read_json(file.path(root, 'badge.json'))$message == '100.0%',
    'sample_color=brightgreen' %in% readLines(output)
  )
  policy$groups$duplicate <- policy$groups$sample
  before <- hashes()
  fails(apipak::coverage_report(root, policy, mode = 'apply'), 'overlap')
  stopifnot(identical(before, hashes()))
  fails(
    apipak::generation_command(root, c('--check', '--dry-run'), 'tests'),
    'one generation mode'
  )
  test_path <- file.path(root, 'tests/testthat/test-contract-refresh.R')
  gap_policy <- list(
    helpers = list('catalogue_request'),
    report_dir = 'reports',
    readiness_report = 'readiness.json'
  )
  before <- hashes()
  stopifnot(
    apipak::test_gap_report(root, gap_policy)$gaps_count == 0L,
    identical(before, hashes())
  )
  cat('\n# User edit\n', file = test_path, append = TRUE)
  before <- hashes()
  fails(apipak::generation_command(root, '--force', 'tests'), 'Protected')
  stopifnot(identical(before, hashes()))
  writeLines('note <- "test_that(fake)"', test_path)
  stopifnot(
    apipak::test_gap_report(root, gap_policy)$gaps$refresh$reason ==
      'empty_test_file'
  )
  writeLines(service[-length(service)], file.path(root, 'catalogue.yml'))
  before <- hashes()
  fails(
    apipak::generation_command(root, '--generate', 'tests'),
    'missing fixed contracts'
  )
  stopifnot(
    identical(before, hashes()),
    'gaps_remaining=1' %in% readLines(output)
  )
  cat(
    'Commands: scoped outputs, CLI modes, CI fields, deterministic apply and protected/missing-contract failures passed.\n'
  )
}
if (sys.nframe() == 0L) {
  commands_acceptance()
}
