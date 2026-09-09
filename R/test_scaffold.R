# Generated test file cleanup and scaffolding.

tg_list_test_files <- function(root = ".") {
  dir <- tg_file_path(root, tg_config$test_dir)
  if (!dir.exists(dir)) {
    return(character(0))
  }
  list.files(dir, pattern = "^test-.*\\.R$", full.names = TRUE)
}

tg_classify_test_file <- function(path) {
  text <- tg_read_text(path)
  if (tg_has_generated_header(text)) {
    return("generated")
  }
  if (tg_has_legacy_metadata_header(text)) {
    return("legacy_generated")
  }
  "manual"
}

tg_remove_legacy_generated_tests <- function(root = ".", dry_run = FALSE) {
  files <- tg_list_test_files(root)
  legacy <- files[vapply(
    files,
    function(path) identical(tg_classify_test_file(path), "legacy_generated"),
    logical(1)
  )]

  if (!dry_run && length(legacy) > 0) {
    unlink(legacy)
  }

  legacy
}

tg_remove_obsolete_generated_tests <- function(
  desired,
  root = ".",
  dry_run = FALSE
) {
  desired_paths <- tg_norm_path(file.path(
    root,
    vapply(desired, `[[`, character(1), "file")
  ))
  files <- tg_list_test_files(root)
  generated <- files[vapply(
    files,
    function(path) identical(tg_classify_test_file(path), "generated"),
    logical(1)
  )]
  obsolete <- generated[!(tg_norm_path(generated) %in% desired_paths)]

  if (!dry_run && length(obsolete) > 0) {
    unlink(obsolete)
  }

  obsolete
}

tg_format_generated_text <- function(text) {
  if (!nzchar(Sys.which("air"))) {
    return(text)
  }

  formatted <- system2(
    "air",
    c("format", "--stdin-file-path", shQuote("generated-test.R")),
    input = text,
    stdout = TRUE
  )
  status <- attr(formatted, "status")
  if (!is.null(status) && status != 0L) {
    stop("Air could not format generated wrapper-test text.", call. = FALSE)
  }
  paste(formatted, collapse = "\n")
}

# Format one staged tree in one subprocess, preserving the original file map.
format_output <- function(root, desired, formatter) {
  if (!identical(formatter$name, 'air')) {
    stop('Supported formatter is air')
  }
  command <- Sys.which('air')
  if (!nzchar(command)) {
    stop('Configured Air formatter is not installed')
  }
  version <- system2(command, '--version', stdout = TRUE)
  if (!identical(version, paste('air', formatter$version))) {
    stop('Configured Air version differs from installed formatter')
  }
  stage <- tempfile('apipak-format-')
  dir.create(stage)
  on.exit(unlink(stage, recursive = TRUE), add = TRUE)
  settings <- intersect(
    c('air.toml', '.air.toml'),
    list.files(root, all.files = TRUE)
  )
  if (length(settings) && !all(file.copy(file.path(root, settings), stage))) {
    stop('Cannot stage formatter settings')
  }
  sources <- names(desired)[endsWith(names(desired), '.R')]
  for (name in sources) {
    path <- project_path(stage, name)
    dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
    writeLines(enc2utf8(desired[[name]]), path, useBytes = TRUE)
  }
  log <- tempfile()
  on.exit(unlink(log), add = TRUE)
  status <- system2(
    command,
    c('format', shQuote(stage)),
    stdout = log,
    stderr = log
  )
  if (status != 0L) {
    stop('Air formatting failed: ', file_text(log))
  }
  for (name in sources) {
    desired[[name]] <- file_text(project_path(stage, name))
  }
  attr(desired, 'formatter') <- formatter
  desired
}

tg_write_generated_tests <- function(
  desired,
  root = ".",
  dry_run = FALSE,
  force = FALSE
) {
  results <- list()

  for (spec in desired) {
    path <- tg_file_path(root, spec$file)
    existed <- file.exists(path)
    status <- if (existed) tg_classify_test_file(path) else "missing"

    if (identical(status, "manual")) {
      results[[spec$function_name]] <- list(
        function_name = spec$function_name,
        path = path,
        action = "skipped_manual",
        written = FALSE
      )
      next
    }

    current <- if (existed) tg_read_text(path) else ""
    changed <- isTRUE(force) || !tg_generated_text_identical(current, spec$text)
    action <- if (!existed) {
      "created"
    } else if (isTRUE(force) && !identical(status, "manual")) {
      "updated"
    } else if (changed) {
      "updated"
    } else {
      "unchanged"
    }

    if (!dry_run && changed) {
      dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
      writeLines(spec$text, path, useBytes = TRUE)
    }

    results[[spec$function_name]] <- list(
      function_name = spec$function_name,
      path = path,
      action = action,
      written = changed && !dry_run
    )
  }

  results
}

tg_scaffold_generated_tests <- function(
  desired,
  root = ".",
  dry_run = FALSE,
  force = FALSE
) {
  desired <- lapply(desired, function(spec) {
    spec$text <- tg_format_generated_text(spec$text)
    spec
  })
  removed_legacy <- tg_remove_legacy_generated_tests(root, dry_run = TRUE)
  removed_obsolete <- tg_remove_obsolete_generated_tests(
    desired,
    root,
    dry_run = TRUE
  )
  write_results <- tg_write_generated_tests(
    desired,
    root,
    dry_run = TRUE,
    force = force
  )
  output <- stats::setNames(
    lapply(desired, `[[`, 'text'),
    vapply(desired, `[[`, character(1), 'file')
  )
  removals <- vapply(
    c(removed_legacy, removed_obsolete),
    tg_rel_path,
    character(1),
    root = root
  )
  apipak::apply_files(
    root,
    output,
    remove = setdiff(removals, names(output)),
    mode = if (dry_run) 'plan' else 'apply',
    headers = c(tg_config$generated_header, tg_config$legacy_metadata_header)
  )
  if (!dry_run) {
    write_results <- lapply(write_results, function(x) {
      x$written <- x$action %in% c('created', 'updated')
      x
    })
  }

  list(
    removed = c(removed_legacy, removed_obsolete),
    removed_legacy = removed_legacy,
    removed_obsolete = removed_obsolete,
    writes = write_results
  )
}
