write_github_outputs <- function(values) {
  path <- Sys.getenv('GITHUB_OUTPUT')
  if (nzchar(path)) {
    stopifnot(!any(grepl('[\r\n]', c(names(values), values))))
    cat(
      paste0(names(values), '=', values, '\n'),
      file = path,
      append = TRUE,
      sep = ''
    )
  }
  invisible(values)
}

generation_command <- function(
  root,
  args = character(),
  kind = c('stubs', 'tests'),
  config = 'specmill.yml',
  callbacks = new.env(parent = emptyenv())
) {
  kind <- match.arg(kind)
  if (any(args %in% c('--help', '-h'))) {
    cat(
      if (kind == 'tests') {
        'Generate fixed offline contracts: --generate (default), --check, --dry-run, --force.\n'
      } else {
        'Generate wrappers and documentation: apply (default), --check, --plan, --rebuild=<prefix>.\n'
      }
    )
    return(invisible(NULL))
  }
  modes <- intersect(
    args,
    if (kind == 'tests') {
      c('--generate', '--check', '--dry-run')
    } else {
      c('--check', '--plan')
    }
  )
  if (length(modes) > 1L) {
    stop('Choose only one generation mode')
  }
  allowed <- if (kind == 'tests') {
    c('--generate', '--check', '--dry-run', '--force')
  } else {
    c(
      '--check',
      '--plan',
      grep('^--rebuild=[a-z][a-z0-9_]*$', args, value = TRUE)
    )
  }
  if (length(setdiff(args, allowed))) {
    stop(
      'Unknown generation argument: ',
      paste(setdiff(args, allowed), collapse = ', ')
    )
  }
  mode <- if ('--check' %in% args) {
    'check'
  } else if (any(c('--dry-run', '--plan') %in% args)) {
    'plan'
  } else {
    'apply'
  }
  root <- normalizePath(root, winslash = '/', mustWork = TRUE)
  before <- list.files(root, recursive = TRUE)
  gaps <- if (kind == 'tests') {
    inspection <- inspect_client(root, config, callbacks)
    sum(vapply(inspection$coverage, `[[`, integer(1), 'total')) -
      sum(vapply(inspection$operations, `[[`, logical(1), 'contract_declared'))
  } else {
    0L
  }
  if (gaps && mode != 'plan') {
    write_github_outputs(c(
      tests_generated = 0,
      tests_skipped = 0,
      tests_removed = 0,
      check_status = 'fail',
      gaps_remaining = gaps
    ))
    stop('Selected operations are missing fixed contracts: ', gaps)
  }
  result <- tryCatch(
    generate_client(
      root,
      config = config,
      callbacks = callbacks,
      mode = mode,
      artifacts = if (kind == 'tests') {
        'tests'
      } else {
        c('wrappers', 'documentation')
      }
    ),
    error = function(error) {
      if (kind == 'tests') {
        write_github_outputs(c(
          tests_generated = 0,
          tests_skipped = 0,
          tests_removed = 0,
          check_status = 'fail',
          gaps_remaining = 'unknown'
        ))
      }
      stop(error)
    }
  )
  records <- Filter(
    function(x) startsWith(x$file, if (kind == 'tests') 'tests/' else 'R/'),
    result$files
  )
  changed <- Filter(function(x) x$action == 'write', records)
  created <- sum(!vapply(changed, `[[`, character(1), 'file') %in% before)
  updated <- length(changed) - created
  actions <- vapply(records, `[[`, character(1), 'action')
  print(table(actions))
  if (mode == 'plan') {
    pending <- Filter(
      function(x) !x$action %in% c('unchanged', 'retained'),
      result$files
    )
    if (length(pending)) {
      print(
        data.frame(
          file = vapply(pending, `[[`, character(1), 'file'),
          action = vapply(pending, `[[`, character(1), 'action')
        ),
        row.names = FALSE
      )
    }
    if (length(result$diagnostics)) print(result$diagnostics)
  }
  if (kind == 'stubs' && mode == 'apply') {
    write_github_outputs(c(
      stubs_generated = length(changed),
      stubs_created = created,
      stubs_appended = updated,
      stubs_skipped = sum(actions == 'unchanged'),
      stubs_protected = sum(actions == 'protected'),
      drift_count = length(result$drift),
      drift_endpoints = length(unique(vapply(
        result$drift,
        `[[`,
        character(1),
        'endpoint'
      )))
    ))
  }
  if (kind == 'tests') {
    values <- c(
      tests_generated = length(changed),
      tests_created = created,
      tests_updated = updated,
      tests_skipped = sum(actions == 'protected'),
      tests_unchanged = sum(actions == 'unchanged'),
      tests_removed = sum(actions == 'remove'),
      check_status = if (mode == 'plan') {
        'dry_run'
      } else if (gaps) {
        'fail'
      } else {
        'pass'
      },
      gaps_remaining = gaps
    )
    write_github_outputs(values)
  }
  invisible(result)
}
