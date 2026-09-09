test_gap_report <- function(
  root,
  policy,
  callbacks = new.env(parent = emptyenv()),
  config = 'apipak.yml',
  mode = c('plan', 'apply')
) {
  mode <- match.arg(mode)
  root <- normalizePath(root, winslash = '/', mustWork = TRUE)
  if (is.character(policy)) {
    policy <- config_data(read_config_yaml(policy))
  }
  config_fields(
    policy,
    c('helpers', 'report_dir', 'readiness_report'),
    'test-gap policy'
  )
  helpers <- vapply(
    policy$helpers,
    config_string,
    character(1),
    label = 'request helper'
  )
  directory <- project_path(
    root,
    config_string(policy$report_dir, 'report directory')
  )
  config_string(policy$readiness_report, 'readiness report')
  inspection <- inspect_client(root, config, callbacks)
  has_tests <- function(path) {
    length(tg_find_calls(as.list(parse(path)), 'test_that')) > 0L
  }
  gaps <- list()
  add <- function(name, source, file, reason) {
    gaps[[name]] <<- list(
      function_name = name,
      file_path = if (is.null(source)) NULL else file.path(root, source),
      test_file = if (is.null(file)) NULL else file.path(root, file),
      reason = reason
    )
  }
  for (operation in inspection$operations) {
    if (!operation$contract_declared) {
      add(operation$name, operation$file, NULL, 'no_fixed_contract')
    } else if (is.null(operation$contract_file)) {
      add(operation$name, operation$file, NULL, 'no_test_file')
    } else if (!has_tests(file.path(root, operation$contract_file))) {
      add(
        operation$name,
        operation$file,
        operation$contract_file,
        'empty_test_file'
      )
    }
  }
  missing <- Filter(
    function(x) {
      x$status != 'excluded' && !x$id %in% names(inspection$operations)
    },
    inspection$inventory
  )
  for (operation in missing) {
    add(operation$id, NULL, NULL, 'unsupported_operation')
  }
  manual <- Filter(
    function(x) length(intersect(x$calls, helpers)) > 0L,
    inspection$manual_exports
  )
  for (wrapper in manual) {
    file <- paste0('tests/testthat/test-', wrapper$name, '.R')
    if (!file.exists(file.path(root, file))) {
      add(wrapper$name, wrapper$file, file, 'no_test_file')
    } else if (!has_tests(file.path(root, file))) {
      add(wrapper$name, wrapper$file, file, 'empty_test_file')
    }
  }
  report <- list(
    timestamp = format(Sys.time(), '%Y-%m-%dT%H:%M:%SZ', tz = 'UTC'),
    manifest_authoritative = FALSE,
    manifest_replacement = policy$readiness_report,
    gaps_count = length(gaps),
    gaps = gaps,
    stale_protected = list()
  )
  if (mode == 'apply') {
    dir.create(directory, recursive = TRUE, showWarnings = FALSE)
    path <- file.path(
      directory,
      paste0('test_gaps_', format(Sys.time(), '%Y%m%d', tz = 'UTC'), '.json')
    )
    jsonlite::write_json(report, path, pretty = TRUE, auto_unbox = TRUE)
    write_github_outputs(c(
      gaps_found = if (length(gaps)) 'true' else 'false',
      gaps_count = length(gaps)
    ))
    cat('Report written: ', path, '\n', sep = '')
  }
  cat(sprintf('Total gaps found: %d\n', length(gaps)))
  invisible(report)
}
