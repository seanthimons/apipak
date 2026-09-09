# Readiness report compatibility, extracted from ComptoxR under its MIT license.
# Client-specific report policy is supplied as data in the bound context.
audit_policy <- list()

read_audit_policy <- function(path) {
  policy <- config_data(read_config_yaml(path))
  config_fields(
    policy,
    c(
      'credential_name',
      'credential_pattern',
      'issue',
      'vcr_issue',
      'badge_files',
      'coverage_files',
      'testing_docs',
      'test_tiers',
      'cran_readiness_criteria'
    ),
    'readiness policy'
  )
  for (name in intersect(
    c('credential_name', 'credential_pattern'),
    names(policy)
  )) {
    config_string(policy[[name]], name)
  }
  for (name in intersect(
    c('coverage_files', 'testing_docs', 'cran_readiness_criteria'),
    names(policy)
  )) {
    policy[[name]] <- vapply(
      policy[[name]],
      config_string,
      character(1),
      label = name
    )
  }
  for (name in names(policy$test_tiers)) {
    for (field in c('requirements', 'activation')) {
      policy$test_tiers[[name]][[field]] <- unlist(
        policy$test_tiers[[name]][[field]],
        use.names = FALSE
      )
    }
  }
  policy
}

`%audit||%` <- function(x, y) {
  if (is.null(x)) {
    y
  } else {
    x
  }
}

audit_schema <- "unit_test_readiness_audit/v1"
export_exclusion_schema <- "export_test_exclusions/v1"
vcr_classification_schema <- "vcr_test_classification/v1"
vcr_classification_allowed_tiers <- c(
  "replay_fixture_integration",
  "live_only",
  "recorder_only"
)
vcr_classification_required_fields <- c(
  "test_file",
  "tier",
  "reason",
  "owner",
  "issue"
)

audit_norm_path <- function(path) {
  normalizePath(path, winslash = "/", mustWork = FALSE)
}

audit_regex_escape <- function(x) {
  gsub("([][{}()+*^$|\\\\.?])", "\\\\\\1", x, perl = TRUE)
}

audit_rel_path <- function(paths, root = ".") {
  if (length(paths) == 0) {
    return(character(0))
  }

  root <- audit_norm_path(root)
  paths <- audit_norm_path(paths)
  sub(paste0("^", audit_regex_escape(root), "/?"), "", paths, perl = TRUE)
}

audit_file_path <- function(root, ...) {
  file.path(root, ...)
}

audit_list_files <- function(root, subdir, pattern = NULL, recursive = FALSE) {
  dir <- audit_file_path(root, subdir)
  if (!dir.exists(dir)) {
    return(character(0))
  }

  files <- list.files(
    dir,
    pattern = pattern,
    recursive = recursive,
    full.names = TRUE,
    all.files = FALSE,
    no.. = TRUE
  )
  sort(audit_rel_path(files, root))
}

audit_read_lines <- function(path) {
  if (!file.exists(path)) {
    return(character(0))
  }

  readLines(path, warn = FALSE)
}

audit_read_text <- function(path) {
  paste(audit_read_lines(path), collapse = "\n")
}

audit_strip_namespace_quotes <- function(x) {
  x <- trimws(x)
  x <- sub('^"(.*)"$', "\\1", x)
  x <- sub("^'(.*)'$", "\\1", x)
  x
}

audit_json_string_vector <- function(x) {
  if (is.null(x)) {
    return(character(0))
  }
  if (is.character(x)) {
    return(x)
  }
  if (
    is.list(x) &&
      all(vapply(
        x,
        function(value) {
          length(value) == 1 && is.character(value)
        },
        logical(1)
      ))
  ) {
    return(unlist(x, use.names = FALSE))
  }

  x
}

audit_parse_namespace <- function(root = ".") {
  namespace_path <- audit_file_path(root, "NAMESPACE")
  lines <- audit_read_lines(namespace_path)

  export_lines <- grep("^\\s*export\\(", lines, value = TRUE)
  exports <- sub("^\\s*export\\((.*)\\)\\s*$", "\\1", export_lines, perl = TRUE)
  exports <- sort(unique(audit_strip_namespace_quotes(exports)))

  operator_exports <- sort(exports[grepl("^%.*%$", exports)])
  function_exports <- sort(setdiff(exports, operator_exports))

  s3_lines <- grep("^\\s*S3method\\(", lines, value = TRUE)
  s3_methods <- sub(
    "^\\s*S3method\\((.*)\\)\\s*$",
    "\\1",
    s3_lines,
    perl = TRUE
  )
  s3_methods <- sort(unique(trimws(s3_methods)))

  list(
    exports = exports,
    function_exports = function_exports,
    operator_exports = operator_exports,
    s3_methods = s3_methods,
    exports_total = length(exports),
    function_exports_total = length(function_exports),
    s3_methods_total = length(s3_methods)
  )
}

audit_prefix <- function(x) {
  stem <- tools::file_path_sans_ext(basename(x))
  stem <- sub("^test-", "", stem)
  ifelse(grepl("_", stem), sub("_.*$", "", stem), sub("-.*$", "", stem))
}

audit_count_values <- function(values) {
  if (length(values) == 0) {
    return(list())
  }

  tab <- table(values)
  ord <- order(-as.integer(tab), names(tab))
  tab <- tab[ord]
  stats::setNames(as.list(as.integer(tab)), names(tab))
}

audit_extract_cassette_references <- function(text) {
  matches <- gregexpr(
    "use_cassette\\s*\\(\\s*['\"]([^'\"]+)['\"]",
    text,
    perl = TRUE
  )
  raw <- regmatches(text, matches)[[1]]
  if (length(raw) == 0 || identical(raw, character(0))) {
    return(character(0))
  }

  sub(".*use_cassette\\s*\\(\\s*['\"]([^'\"]+)['\"].*", "\\1", raw, perl = TRUE)
}

audit_has_generated_test_header <- function(lines) {
  if (length(lines) == 0) {
    return(FALSE)
  }

  header_lines <- lines[seq_len(min(5, length(lines)))]
  any(
    header_lines %in%
      c(
        "# Generated using metadata-based test generator",
        "# Generated by wrapmaint; do not edit by hand.",
        "# Generated by dev/generate_tests.R; do not edit by hand."
      )
  )
}

audit_test_style <- function(root = ".", test_files = NULL) {
  test_files <- test_files %audit||%
    audit_list_files(root, "tests/testthat", "^test-.*\\.R$")

  generated <- logical(length(test_files))
  backticked_endpoint <- logical(length(test_files))
  without_parameters <- logical(length(test_files))
  using_vcr <- logical(length(test_files))
  using_mocked_bindings <- logical(length(test_files))
  using_skip_on_cran <- logical(length(test_files))
  using_skip_if_no_key <- logical(length(test_files))
  using_skip_if_offline <- logical(length(test_files))
  mentioning_ctx_api_key <- logical(length(test_files))
  cassette_refs <- list()

  for (i in seq_along(test_files)) {
    lines <- audit_read_lines(audit_file_path(root, test_files[[i]]))
    text <- paste(lines, collapse = "\n")
    generated[[i]] <- audit_has_generated_test_header(lines)
    backticked_endpoint[[i]] <- grepl("`[^`\\n]*-[^`\\n]*`", text, perl = TRUE)
    without_parameters[[i]] <- grepl(
      "works without parameters",
      text,
      fixed = TRUE
    )
    using_vcr[[i]] <- grepl("\\buse_cassette\\s*\\(", text, perl = TRUE)
    using_mocked_bindings[[i]] <- grepl(
      "\\b(with_mocked_bindings|local_mocked_bindings)\\s*\\(",
      text,
      perl = TRUE
    )
    using_skip_on_cran[[i]] <- grepl(
      "\\bskip_on_cran\\s*\\(",
      text,
      perl = TRUE
    )
    using_skip_if_no_key[[i]] <- grepl(
      "\\bskip_if_no_key\\s*\\(",
      text,
      perl = TRUE
    )
    using_skip_if_offline[[i]] <- grepl(
      "\\bskip_if_offline\\s*\\(",
      text,
      perl = TRUE
    )
    mentioning_ctx_api_key[[i]] <- grepl(
      audit_policy$credential_name %audit||% 'api_key',
      text,
      fixed = TRUE
    )
    cassette_refs[[test_files[[i]]]] <- audit_extract_cassette_references(text)
  }

  unique_refs <- sort(unique(unlist(cassette_refs, use.names = FALSE)))
  reference_files <- lapply(unique_refs, function(ref) {
    sort(names(cassette_refs)[vapply(
      cassette_refs,
      function(x) ref %in% x,
      logical(1)
    )])
  })
  names(reference_files) <- unique_refs

  list(
    generated_header_test_files = sum(generated),
    non_generated_header_test_files = length(test_files) - sum(generated),
    backticked_endpoint_call_files = sum(backticked_endpoint),
    generated_backticked_endpoint_call_files = sum(
      generated & backticked_endpoint
    ),
    non_generated_backticked_endpoint_call_files = sum(
      !generated & backticked_endpoint
    ),
    files_with_without_parameters_generated_case = sum(without_parameters),
    generated_files_with_without_parameters_case = sum(
      generated & without_parameters
    ),
    non_generated_files_with_without_parameters_case = sum(
      !generated & without_parameters
    ),
    files_using_vcr = sum(using_vcr),
    generated_files_using_vcr = sum(generated & using_vcr),
    non_generated_files_using_vcr = sum(!generated & using_vcr),
    files_using_mocked_bindings = sum(using_mocked_bindings),
    files_using_skip_on_cran = sum(using_skip_on_cran),
    files_using_skip_if_no_key = sum(using_skip_if_no_key),
    files_using_skip_if_offline = sum(using_skip_if_offline),
    files_mentioning_ctx_api_key = sum(mentioning_ctx_api_key),
    unique_cassette_references = length(unique_refs),
    generated_backticked_endpoint_call_file_names = unname(test_files[
      generated & backticked_endpoint
    ]),
    files_using_vcr_names = unname(test_files[using_vcr]),
    generated_files_using_vcr_names = unname(test_files[generated & using_vcr]),
    cassette_references = unique_refs,
    cassette_reference_files = reference_files
  )
}

audit_read_json <- function(path) {
  if (!file.exists(path)) {
    return(NULL)
  }

  tryCatch(
    jsonlite::fromJSON(path, simplifyVector = FALSE),
    error = function(e) list(.parse_error = e$message)
  )
}

read_export_exclusions <- function(
  root = ".",
  path = audit_file_path(root, "dev/export_test_exclusions.json")
) {
  data <- audit_read_json(path)
  if (is.null(data)) {
    return(list(
      artifact_schema = export_exclusion_schema,
      required_fields = c("export", "reason", "owner", "issue"),
      exclusions = list()
    ))
  }

  data
}

validate_export_exclusions <- function(exclusions, known_exports = NULL) {
  required <- c("export", "reason", "owner", "issue")
  errors <- character(0)

  if (!identical(exclusions$artifact_schema, export_exclusion_schema)) {
    errors <- c(
      errors,
      sprintf("artifact_schema must be %s", export_exclusion_schema)
    )
  }

  entries <- exclusions$exclusions %audit||% list()
  if (!is.list(entries)) {
    errors <- c(errors, "exclusions must be a list")
    entries <- list()
  }

  cleaned <- list()
  seen <- character(0)
  for (i in seq_along(entries)) {
    entry <- entries[[i]]
    missing <- required[!required %in% names(entry)]
    if (length(missing) > 0) {
      errors <- c(
        errors,
        sprintf(
          "exclusions[%d] missing required field(s): %s",
          i,
          paste(missing, collapse = ", ")
        )
      )
      next
    }

    empty <- required[vapply(
      required,
      function(field) {
        value <- entry[[field]]
        length(value) != 1 || !is.character(value) || !nzchar(value)
      },
      logical(1)
    )]
    if (length(empty) > 0) {
      errors <- c(
        errors,
        sprintf(
          "exclusions[%d] has empty/non-scalar field(s): %s",
          i,
          paste(empty, collapse = ", ")
        )
      )
      next
    }

    if (entry$export %in% seen) {
      errors <- c(
        errors,
        sprintf("duplicate exclusion for export: %s", entry$export)
      )
      next
    }

    if (!is.null(known_exports) && !(entry$export %in% known_exports)) {
      errors <- c(
        errors,
        sprintf(
          "exclusion references unknown function export: %s",
          entry$export
        )
      )
    }

    seen <- c(seen, entry$export)
    cleaned[[entry$export]] <- entry[required]
  }

  cleaned <- cleaned[sort(names(cleaned))]

  list(
    valid = length(errors) == 0,
    errors = errors,
    entries = unname(cleaned),
    excluded_exports = sort(names(cleaned))
  )
}

read_vcr_test_classification <- function(
  root = ".",
  path = audit_file_path(root, "dev/vcr_test_classification.json")
) {
  data <- audit_read_json(path)
  if (is.null(data)) {
    return(list(
      artifact_schema = vcr_classification_schema,
      description = paste(
        "Machine-readable classification for tests that call vcr::use_cassette().",
        "Every current VCR test file must have one entry."
      ),
      issue = audit_policy$vcr_issue %audit||% list(),
      allowed_tiers = vcr_classification_allowed_tiers,
      required_fields = vcr_classification_required_fields,
      classifications = list()
    ))
  }

  data
}

audit_normalize_rel_file <- function(path) {
  gsub("\\\\", "/", path)
}

validate_vcr_test_classification <- function(
  classification,
  current_vcr_test_files = character(0),
  current_test_files = NULL
) {
  current_vcr_test_files <- sort(unique(audit_normalize_rel_file(
    current_vcr_test_files
  )))
  current_test_files <- sort(unique(audit_normalize_rel_file(
    current_test_files %audit||% current_vcr_test_files
  )))
  required <- vcr_classification_required_fields
  errors <- character(0)

  if (!identical(classification$artifact_schema, vcr_classification_schema)) {
    errors <- c(
      errors,
      sprintf("artifact_schema must be %s", vcr_classification_schema)
    )
  }

  issue <- classification$issue %audit||% list()
  expected_issue <- audit_policy$vcr_issue
  if (
    !is.null(expected_issue) &&
      (!is.list(issue) ||
        length(issue$github_issue) != 1 ||
        !is.numeric(issue$github_issue) ||
        !identical(
          as.integer(issue$github_issue),
          as.integer(expected_issue$github_issue)
        ) ||
        !identical(issue$bean, expected_issue$bean))
  ) {
    errors <- c(
      errors,
      paste(
        'issue metadata must reference GitHub issue',
        expected_issue$github_issue,
        'and bean',
        expected_issue$bean
      )
    )
  }

  allowed_tiers <- audit_json_string_vector(classification$allowed_tiers)
  if (
    !is.character(allowed_tiers) ||
      !identical(
        sort(unique(allowed_tiers)),
        sort(vcr_classification_allowed_tiers)
      )
  ) {
    errors <- c(
      errors,
      sprintf(
        "allowed_tiers must contain exactly: %s",
        paste(vcr_classification_allowed_tiers, collapse = ", ")
      )
    )
    allowed_tiers <- vcr_classification_allowed_tiers
  }

  declared_required <- audit_json_string_vector(classification$required_fields)
  if (
    !is.character(declared_required) ||
      !identical(sort(unique(declared_required)), sort(required))
  ) {
    errors <- c(
      errors,
      sprintf(
        "required_fields must contain exactly: %s",
        paste(required, collapse = ", ")
      )
    )
  }

  entries <- classification$classifications %audit||% list()
  if (!is.list(entries)) {
    errors <- c(errors, "classifications must be a list")
    entries <- list()
  }

  cleaned <- list()
  seen <- character(0)
  for (i in seq_along(entries)) {
    entry <- entries[[i]]
    if (!is.list(entry)) {
      errors <- c(errors, sprintf("classifications[%d] must be an object", i))
      next
    }

    missing <- required[!required %in% names(entry)]
    if (length(missing) > 0) {
      errors <- c(
        errors,
        sprintf(
          "classifications[%d] missing required field(s): %s",
          i,
          paste(missing, collapse = ", ")
        )
      )
      next
    }

    empty <- required[vapply(
      required,
      function(field) {
        value <- entry[[field]]
        length(value) != 1 || !is.character(value) || !nzchar(value)
      },
      logical(1)
    )]
    if (length(empty) > 0) {
      errors <- c(
        errors,
        sprintf(
          "classifications[%d] has empty/non-scalar field(s): %s",
          i,
          paste(empty, collapse = ", ")
        )
      )
      next
    }

    entry$test_file <- audit_normalize_rel_file(entry$test_file)

    if (!(entry$tier %in% allowed_tiers)) {
      errors <- c(
        errors,
        sprintf(
          "classifications[%d] has invalid tier '%s'; expected one of: %s",
          i,
          entry$tier,
          paste(allowed_tiers, collapse = ", ")
        )
      )
    }

    if (entry$test_file %in% seen) {
      errors <- c(
        errors,
        sprintf(
          "duplicate VCR classification for test file: %s",
          entry$test_file
        )
      )
      next
    }

    seen <- c(seen, entry$test_file)
    cleaned[[entry$test_file]] <- entry[required]
  }

  cleaned <- cleaned[sort(names(cleaned))]
  classified_files <- sort(names(cleaned))
  unclassified_files <- sort(setdiff(current_vcr_test_files, classified_files))
  stale_files <- sort(setdiff(classified_files, current_vcr_test_files))
  stale_entries <- lapply(stale_files, function(file) {
    list(
      test_file = file,
      reason = if (file %in% current_test_files) {
        "file no longer uses vcr::use_cassette()"
      } else {
        "file is not a current tests/testthat/test-*.R file"
      }
    )
  })

  gap_errors <- character(0)
  if (length(unclassified_files) > 0) {
    gap_errors <- c(
      gap_errors,
      sprintf(
        "unclassified VCR test file(s): %s",
        paste(unclassified_files, collapse = ", ")
      )
    )
  }
  if (length(stale_files) > 0) {
    gap_errors <- c(
      gap_errors,
      sprintf(
        "stale VCR classification file(s): %s",
        paste(stale_files, collapse = ", ")
      )
    )
  }

  status <- if (length(errors) > 0) {
    "invalid"
  } else if (length(gap_errors) > 0) {
    "gaps"
  } else {
    "ok"
  }

  list(
    artifact_schema = classification$artifact_schema %audit||% NULL,
    valid = identical(status, "ok"),
    status = status,
    errors = errors,
    gap_errors = gap_errors,
    allowed_tiers = vcr_classification_allowed_tiers,
    required_fields = required,
    current_vcr_test_files_total = length(current_vcr_test_files),
    current_vcr_test_files = current_vcr_test_files,
    classified_files_total = length(classified_files),
    classified_files = classified_files,
    unclassified_files_total = length(unclassified_files),
    unclassified_files = unclassified_files,
    stale_classifications_total = length(stale_files),
    stale_classification_files = stale_files,
    stale_classification_entries = stale_entries,
    classifications = unname(cleaned)
  )
}

audit_test_contents <- function(root = ".", test_files) {
  contents <- lapply(test_files, function(file) {
    audit_read_text(audit_file_path(root, file))
  })
  names(contents) <- test_files
  contents
}

classify_exports_against_tests <- function(
  function_exports,
  test_files,
  root = ".",
  exclusions = list()
) {
  function_exports <- sort(unique(function_exports))
  test_files <- sort(unique(test_files))
  test_stems <- tools::file_path_sans_ext(basename(test_files))
  normalized_test_stems <- gsub("-", "_", sub("^test-", "", test_stems))
  contents <- audit_test_contents(root, test_files)
  excluded_exports <- sort(vapply(
    exclusions,
    function(entry) entry$export,
    character(1)
  ))
  exclusions_by_export <- stats::setNames(exclusions, excluded_exports)

  records <- lapply(function_exports, function(export) {
    named_files <- sort(test_files[normalized_test_stems == export])
    pattern <- paste0(
      "(?<![A-Za-z0-9_.])",
      audit_regex_escape(export),
      "(?![A-Za-z0-9_.])"
    )
    reference_files <- sort(names(contents)[vapply(
      contents,
      function(text) {
        grepl(pattern, text, perl = TRUE)
      },
      logical(1)
    )])
    excluded <- export %in% excluded_exports

    list(
      export = export,
      family = audit_prefix(export),
      named_test_file = length(named_files) > 0,
      named_test_files = named_files,
      literal_test_reference = length(reference_files) > 0,
      literal_reference_files = reference_files,
      intentionally_excluded = excluded,
      exclusion = exclusions_by_export[[export]] %audit||% list()
    )
  })
  names(records) <- function_exports

  without_named <- sort(function_exports[
    !vapply(records, `[[`, logical(1), "named_test_file")
  ])
  without_reference <- sort(function_exports[
    !vapply(records, `[[`, logical(1), "literal_test_reference")
  ])
  gaps <- sort(setdiff(without_reference, excluded_exports))

  families <- sort(unique(vapply(records, `[[`, character(1), "family")))
  family_summary <- lapply(families, function(family) {
    family_records <- records[vapply(
      records,
      function(record) identical(record$family, family),
      logical(1)
    )]
    list(
      exports = length(family_records),
      named_test_files = sum(vapply(
        family_records,
        `[[`,
        logical(1),
        "named_test_file"
      )),
      test_references = sum(vapply(
        family_records,
        `[[`,
        logical(1),
        "literal_test_reference"
      )),
      intentionally_excluded = sum(vapply(
        family_records,
        `[[`,
        logical(1),
        "intentionally_excluded"
      )),
      without_test_reference = sum(
        !vapply(family_records, `[[`, logical(1), "literal_test_reference")
      ),
      gaps_after_exclusions = sum(vapply(
        family_records,
        function(record) {
          !record$literal_test_reference && !record$intentionally_excluded
        },
        logical(1)
      ))
    )
  })
  names(family_summary) <- families

  list(
    function_exports = length(function_exports),
    exports_with_named_test_file = length(function_exports) -
      length(without_named),
    exports_without_named_test_file = length(without_named),
    exports_with_test_reference = length(function_exports) -
      length(without_reference),
    exports_without_test_reference = length(without_reference),
    intentionally_excluded_exports = length(excluded_exports),
    export_gaps_after_exclusions = length(gaps),
    family_summary = family_summary,
    exports_without_named_test_file_names = without_named,
    exports_without_test_reference_names = without_reference,
    intentionally_excluded_export_names = excluded_exports,
    export_gaps = gaps,
    export_inventory = unname(records)
  )
}

audit_manifest_status <- function(root = ".") {
  manifest_path <- audit_file_path(root, "dev/test_manifest.json")
  manifest <- audit_read_json(manifest_path)
  exists <- !is.null(manifest)

  if (!exists) {
    return(list(
      path = "dev/test_manifest.json",
      exists = FALSE,
      authoritative = FALSE,
      retired = TRUE,
      replacement = "dev/reports/unit_test_readiness_audit.json",
      reason = "artifact retired and absent",
      legacy_files_total = 0,
      parse_error = NULL
    ))
  }

  parse_error <- manifest$.parse_error %audit||% NULL
  retired <- isTRUE(manifest$retired) ||
    identical(manifest$artifact_schema, "test_manifest_retired/v1")
  authoritative <- exists &&
    !retired &&
    !identical(manifest$authority, FALSE) &&
    is.null(parse_error)
  legacy_files_total <- length(manifest$files %audit||% list())
  legacy_files_total <- manifest$legacy_manifest$files_total %audit||%
    legacy_files_total

  list(
    path = "dev/test_manifest.json",
    exists = TRUE,
    authoritative = authoritative,
    retired = retired,
    replacement = manifest$replacement %audit||%
      "dev/reports/unit_test_readiness_audit.json",
    retired_at = manifest$retired_at %audit||% NULL,
    reason = manifest$reason %audit||% NULL,
    legacy_files_total = legacy_files_total,
    parse_error = parse_error
  )
}

audit_scan_fixtures <- function(
  root = ".",
  fixture_files = NULL,
  cassette_references = character(0)
) {
  fixture_files <- fixture_files %audit||%
    audit_list_files(
      root,
      "tests/testthat/fixtures",
      "\\.yml$",
      recursive = TRUE
    )
  cassette_references <- sort(unique(cassette_references))
  fixture_basenames <- basename(fixture_files)
  fixture_stems <- sort(unique(tools::file_path_sans_ext(fixture_basenames)))

  refs_with_fixture <- cassette_references[
    paste0(cassette_references, ".yml") %in% fixture_basenames
  ]
  refs_missing_fixture <- setdiff(cassette_references, refs_with_fixture)
  unreferenced_fixture_files <- sort(fixture_files[
    !(tools::file_path_sans_ext(fixture_basenames) %in% cassette_references)
  ])

  status_errors <- list()
  parse_errors <- list()
  for (file in fixture_files) {
    path <- audit_file_path(root, file)
    lines <- tryCatch(readLines(path, warn = FALSE), error = function(e) {
      parse_errors[[file]] <<- e$message
      character(0)
    })
    status_lines <- grep("^\\s*status:\\s*[0-9]+", lines, value = TRUE)
    statuses <- suppressWarnings(as.integer(sub(
      ".*status:\\s*([0-9]+).*",
      "\\1",
      status_lines,
      perl = TRUE
    )))
    error_statuses <- statuses[!is.na(statuses) & statuses >= 400]
    if (length(error_statuses) > 0) {
      status_errors[[file]] <- list(file = file, status = error_statuses[[1]])
    }

    if (requireNamespace("yaml", quietly = TRUE)) {
      tryCatch(
        yaml::read_yaml(path),
        error = function(e) parse_errors[[file]] <<- e$message
      )
    }
  }

  status_errors <- unname(status_errors[sort(names(status_errors))])
  parse_errors <- lapply(sort(names(parse_errors)), function(file) {
    list(file = file, error = parse_errors[[file]])
  })

  list(
    fixture_files = fixture_files,
    fixture_stems = fixture_stems,
    unique_cassette_references = length(cassette_references),
    referenced_cassettes_with_fixture = length(refs_with_fixture),
    referenced_cassettes_missing_fixture = length(refs_missing_fixture),
    referenced_cassettes_missing_fixture_names = sort(refs_missing_fixture),
    fixture_files_not_referenced_by_literal_test = length(
      unreferenced_fixture_files
    ),
    fixture_files_not_referenced_by_literal_test_names = unreferenced_fixture_files,
    cassette_files_with_http_error_status = length(status_errors),
    cassette_http_error_status_by_file = status_errors,
    fixture_yaml_parse_errors_by_file = parse_errors
  )
}

audit_workflows <- function(root = ".", workflow_files = NULL) {
  workflow_files <- workflow_files %audit||%
    audit_list_files(root, ".github/workflows", "\\.ya?ml$")
  records <- lapply(sort(workflow_files), function(file) {
    text <- audit_read_text(audit_file_path(root, file))
    list(
      file = file,
      runs_devtools_test = grepl("devtools::test\\s*\\(", text, perl = TRUE),
      runs_targeted_test_file = grepl(
        "testthat::test_file\\s*\\(",
        text,
        perl = TRUE
      ),
      runs_package_check = grepl(
        "devtools::check\\s*\\(|R CMD check|check-r-package",
        text,
        perl = TRUE
      ),
      uses_covr = grepl("covr::|package_coverage|codecov", text, perl = TRUE),
      uses_ctx_api_key_secret = grepl(
        audit_policy$credential_pattern %audit||% 'api_key',
        text,
        perl = TRUE
      ),
      has_workflow_dispatch = grepl(
        "(^|\\n)\\s*workflow_dispatch\\s*:",
        text,
        perl = TRUE
      ),
      has_pull_request = grepl(
        "(^|\\n)\\s*pull_request\\s*:",
        text,
        perl = TRUE
      ),
      has_push = grepl("(^|\\n)\\s*push\\s*:", text, perl = TRUE),
      has_matrix = grepl("(^|\\n)\\s*(strategy|matrix)\\s*:", text, perl = TRUE)
    )
  })

  list(
    workflow_files = records,
    workflows_running_devtools_test = sum(vapply(
      records,
      `[[`,
      logical(1),
      "runs_devtools_test"
    )),
    workflows_running_targeted_test_file = sum(vapply(
      records,
      `[[`,
      logical(1),
      "runs_targeted_test_file"
    )),
    workflows_running_package_check = sum(vapply(
      records,
      `[[`,
      logical(1),
      "runs_package_check"
    )),
    workflows_using_covr = sum(vapply(records, `[[`, logical(1), "uses_covr")),
    workflows_using_ctx_api_key_secret = sum(vapply(
      records,
      `[[`,
      logical(1),
      "uses_ctx_api_key_secret"
    ))
  )
}

audit_json_file <- function(root, rel_path) {
  audit_read_json(audit_file_path(root, rel_path)) %audit||% list()
}

audit_coverage_signals <- function(root = ".") {
  codecov_text <- audit_read_text(audit_file_path(root, "codecov.yml"))
  pipeline_text <- audit_read_text(audit_file_path(
    root,
    ".github/workflows/pipeline-tests.yml"
  ))
  coverage_check_text <- audit_read_text(audit_file_path(
    root,
    ".github/workflows/coverage-check.yml"
  ))

  list(
    line_coverage_fresh_run = FALSE,
    line_coverage_note = "Full covr/devtools test coverage is not run by this read-only audit command.",
    codecov_project_target = if (grepl("target:\\s*auto", codecov_text)) {
      "auto with 1% threshold"
    } else {
      "not detected"
    },
    codecov_patch_target = if (grepl("target:\\s*80%", codecov_text)) {
      "80% with 0% threshold"
    } else {
      "not detected"
    },
    coverage_check_workflow = if (grepl("75", coverage_check_text)) {
      "75% minimum, warn-only"
    } else {
      "not detected"
    },
    pipeline_workflow_package_gate = if (grepl("75", pipeline_text)) {
      "75% minimum, enforced"
    } else {
      "not detected"
    },
    pipeline_workflow_dev_endpoint_eval_gate = if (grepl("80", pipeline_text)) {
      "80% minimum, enforced"
    } else {
      "not detected"
    },
    endpoint_coverage_baseline = audit_json_file(
      root,
      "schema/coverage_baseline.json"
    ),
    badge_files = lapply(
      audit_policy$badge_files %audit||% list(),
      function(path) audit_json_file(root, path)
    )
  )
}

audit_testing_docs <- function(
  root = ".",
  current_test_files = NULL,
  generated_header_test_files = NULL
) {
  docs <- audit_policy$testing_docs %audit||% character()
  records <- list()

  for (doc in docs) {
    text <- audit_read_text(audit_file_path(root, doc))
    if (!nzchar(text)) {
      next
    }

    issues <- character(0)
    if (grepl("\\b323\\b", text, perl = TRUE)) {
      issues <- c(issues, "Contains stale 323 test-file claim.")
    }
    if (grepl("CI has no API key", text, fixed = TRUE)) {
      issues <- c(
        issues,
        "Claims CI has no API key despite current secret-backed workflows."
      )
    }
    if (!grepl("unit_test_readiness_audit", text, fixed = TRUE)) {
      issues <- c(
        issues,
        "Does not point to dev/reports/unit_test_readiness_audit.json as the inventory source of truth."
      )
    }

    records[[doc]] <- list(
      file = doc,
      mentions_audit_artifact = grepl(
        "dev/reports/unit_test_readiness_audit.json",
        text,
        fixed = TRUE
      ),
      mentions_audit_command = grepl(
        "dev/unit_test_readiness_audit.R",
        text,
        fixed = TRUE
      ),
      stale_323_claim = grepl("\\b323\\b", text, perl = TRUE),
      issues = issues
    )
  }

  unname(records[sort(names(records))])
}

audit_test_tiers <- function() {
  audit_policy$test_tiers %audit||% list()
}

audit_git_value <- function(root, args) {
  old <- getwd()
  on.exit(setwd(old), add = TRUE)
  setwd(root)
  out <- tryCatch(
    suppressWarnings(system2("git", args, stdout = TRUE, stderr = FALSE)),
    error = function(e) character(0)
  )
  status <- attr(out, "status")
  if (!is.null(status) && !identical(status, 0L)) {
    return(NA_character_)
  }
  if (length(out) == 0) {
    return(NA_character_)
  }
  out[[1]]
}

build_unit_test_readiness_audit <- function(root = ".") {
  root <- audit_norm_path(root)
  namespace <- audit_parse_namespace(root)
  test_files <- audit_list_files(root, "tests/testthat", "^test-.*\\.R$")
  test_helpers <- sort(c(
    audit_list_files(root, "tests/testthat", "^helper-.*\\.R$"),
    audit_list_files(root, "tests/testthat", "^setup\\.R$")
  ))
  test_tool_files <- audit_list_files(root, "tests/testthat/tools", "\\.R$")
  fixture_files <- audit_list_files(
    root,
    "tests/testthat/fixtures",
    "\\.yml$",
    recursive = TRUE
  )
  workflow_files <- audit_list_files(root, ".github/workflows", "\\.ya?ml$")
  coverage_files <- audit_policy$coverage_files %audit||% character()
  coverage_files <- sort(coverage_files[file.exists(audit_file_path(
    root,
    coverage_files
  ))])
  docs <- audit_policy$testing_docs %audit||% character()
  docs <- sort(docs[file.exists(audit_file_path(root, docs))])

  style <- audit_test_style(root, test_files)
  exclusions <- read_export_exclusions(root)
  exclusion_validation <- validate_export_exclusions(
    exclusions,
    namespace$function_exports
  )
  vcr_classification <- read_vcr_test_classification(root)
  vcr_classification_validation <- validate_vcr_test_classification(
    vcr_classification,
    current_vcr_test_files = style$files_using_vcr_names,
    current_test_files = test_files
  )
  export_comparison <- classify_exports_against_tests(
    namespace$function_exports,
    test_files,
    root,
    exclusions = exclusion_validation$entries
  )
  fixture_scan <- audit_scan_fixtures(
    root,
    fixture_files,
    style$cassette_references
  )
  workflow_scan <- audit_workflows(root, workflow_files)
  manifest_status <- audit_manifest_status(root)

  list(
    artifact_schema = audit_schema,
    metadata = list(
      generated_at_utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
      source_branch = audit_git_value(root, c("branch", "--show-current")),
      source_commit = audit_git_value(root, c("rev-parse", "HEAD")),
      issue = audit_policy$issue %audit||% list(),
      generation_notes = c(
        "Read-only audit; no cassettes are deleted or re-recorded.",
        "Named test matching normalizes hyphens to underscores in test file stems.",
        "Test references are literal lexical matches in tests/testthat/test-*.R and may include comments.",
        "dev/test_manifest.json is retired and may be absent; it is not readiness authority."
      )
    ),
    sources = list(
      namespace = "NAMESPACE",
      tests = "tests/testthat/test-*.R",
      test_helpers = test_helpers,
      test_tools = test_tool_files,
      export_exclusions = "dev/export_test_exclusions.json",
      vcr_test_classification = "dev/vcr_test_classification.json",
      manifest = manifest_status,
      fixtures = "tests/testthat/fixtures/**/*.yml",
      workflows = workflow_files,
      coverage_files = coverage_files,
      docs = docs
    ),
    inventory = list(
      namespace = list(
        exports_total = namespace$exports_total,
        function_exports_total = namespace$function_exports_total,
        operator_exports = namespace$operator_exports,
        s3_methods_total = namespace$s3_methods_total,
        s3_methods = namespace$s3_methods
      ),
      files = list(
        r_files = length(audit_list_files(root, "R", "\\.R$")),
        rd_files = length(audit_list_files(root, "man", "\\.Rd$")),
        test_files = length(test_files),
        test_helpers = length(test_helpers),
        test_tool_files = length(test_tool_files),
        fixture_yaml_files = length(fixture_files),
        workflow_files = length(workflow_files)
      ),
      test_style = style[setdiff(
        names(style),
        c("cassette_references", "cassette_reference_files")
      )],
      by_prefix = list(
        tests = audit_count_values(audit_prefix(test_files)),
        exports = audit_count_values(audit_prefix(namespace$function_exports)),
        fixtures = audit_count_values(audit_prefix(fixture_files))
      )
    ),
    comparisons = list(
      exports_vs_tests = export_comparison,
      export_exclusion_validation = list(
        artifact_schema = exclusions$artifact_schema %audit||% NULL,
        valid = exclusion_validation$valid,
        errors = exclusion_validation$errors,
        required_fields = c("export", "reason", "owner", "issue"),
        exclusions = exclusion_validation$entries
      ),
      vcr_classification = vcr_classification_validation,
      manifest = manifest_status,
      fixtures = fixture_scan,
      workflows = workflow_scan
    ),
    coverage_signals = audit_coverage_signals(root),
    testing_docs = audit_testing_docs(
      root,
      length(test_files),
      style$generated_header_test_files
    ),
    test_tiers = audit_test_tiers(),
    cran_readiness_criteria = audit_policy$cran_readiness_criteria %audit||%
      character()
  )
}

write_unit_test_readiness_audit <- function(
  root = ".",
  output = audit_file_path(root, "dev/reports/unit_test_readiness_audit.json")
) {
  report <- build_unit_test_readiness_audit(root)
  output_dir <- dirname(output)
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }
  jsonlite::write_json(
    report,
    output,
    pretty = TRUE,
    auto_unbox = TRUE,
    null = "null",
    digits = NA
  )
  invisible(report)
}

audit_parse_args <- function(args) {
  output <- NULL
  if ("--output" %in% args) {
    idx <- match("--output", args)
    if (idx == length(args)) {
      stop("--output requires a path", call. = FALSE)
    }
    output <- args[[idx + 1]]
  }

  list(
    check_exports = "--check-exports" %in% args,
    fail_on_gaps = "--fail-on-gaps" %in% args,
    output = output
  )
}

unit_test_readiness_audit_main <- function(
  args = commandArgs(trailingOnly = TRUE),
  root = "."
) {
  parsed <- audit_parse_args(args)
  output <- parsed$output %audit||%
    audit_file_path(root, "dev/reports/unit_test_readiness_audit.json")
  report <- write_unit_test_readiness_audit(root, output)
  export_gaps <- report$comparisons$exports_vs_tests$export_gaps
  exclusion_errors <- report$comparisons$export_exclusion_validation$errors
  vcr_classification <- report$comparisons$vcr_classification
  vcr_classification_errors <- vcr_classification$errors
  vcr_classification_gap_errors <- vcr_classification$gap_errors

  cat(sprintf("Wrote %s\n", audit_rel_path(output, root)))
  cat(sprintf(
    "Function exports: %d\n",
    report$comparisons$exports_vs_tests$function_exports
  ))
  cat(sprintf("Export gaps after exclusions: %d\n", length(export_gaps)))
  cat(sprintf(
    "VCR test files: %d\n",
    vcr_classification$current_vcr_test_files_total
  ))
  cat(sprintf("VCR classification status: %s\n", vcr_classification$status))

  if (parsed$check_exports || parsed$fail_on_gaps) {
    if (length(export_gaps) > 0) {
      cat("First export gaps:\n")
      cat(
        paste0("  - ", head(export_gaps, 20), collapse = "\n"),
        "\n",
        sep = ""
      )
    } else {
      cat("No export gaps detected.\n")
    }
  }

  if (length(exclusion_errors) > 0) {
    cat("Export exclusion file is invalid:\n")
    cat(paste0("  - ", exclusion_errors, collapse = "\n"), "\n", sep = "")
    stop('Invalid export exclusions', call. = FALSE)
  }

  if (length(vcr_classification_errors) > 0) {
    cat("VCR test classification file is invalid:\n")
    cat(
      paste0("  - ", vcr_classification_errors, collapse = "\n"),
      "\n",
      sep = ""
    )
    stop('Invalid VCR classification', call. = FALSE)
  }

  if (parsed$fail_on_gaps && length(export_gaps) > 0) {
    stop('Export test gaps remain', call. = FALSE)
  }

  if (parsed$fail_on_gaps && length(vcr_classification_gap_errors) > 0) {
    cat("VCR classification gaps detected:\n")
    cat(
      paste0("  - ", vcr_classification_gap_errors, collapse = "\n"),
      "\n",
      sep = ""
    )
    stop('VCR classification gaps remain', call. = FALSE)
  }

  invisible(report)
}


tool_groups$readiness <- c(
  "audit_policy",
  "read_audit_policy",
  "%audit||%",
  "audit_schema",
  "export_exclusion_schema",
  "vcr_classification_schema",
  "vcr_classification_allowed_tiers",
  "vcr_classification_required_fields",
  "audit_norm_path",
  "audit_regex_escape",
  "audit_rel_path",
  "audit_file_path",
  "audit_list_files",
  "audit_read_lines",
  "audit_read_text",
  "audit_strip_namespace_quotes",
  "audit_json_string_vector",
  "audit_parse_namespace",
  "audit_prefix",
  "audit_count_values",
  "audit_extract_cassette_references",
  "audit_has_generated_test_header",
  "audit_test_style",
  "audit_read_json",
  "read_export_exclusions",
  "validate_export_exclusions",
  "read_vcr_test_classification",
  "audit_normalize_rel_file",
  "validate_vcr_test_classification",
  "audit_test_contents",
  "classify_exports_against_tests",
  "audit_manifest_status",
  "audit_scan_fixtures",
  "audit_workflows",
  "audit_json_file",
  "audit_coverage_signals",
  "audit_testing_docs",
  "audit_test_tiers",
  "audit_git_value",
  "build_unit_test_readiness_audit",
  "write_unit_test_readiness_audit",
  "audit_parse_args",
  "unit_test_readiness_audit_main"
)
