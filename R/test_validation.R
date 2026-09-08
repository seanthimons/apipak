# Static validation for generated contract tests.

tg_validate_generated_text <- function(text, file = "<memory>") {
  errors <- character(0)

  if (!tg_has_generated_header(text)) {
    errors <- c(errors, "missing generated header")
  }
  if (tg_has_legacy_metadata_header(text)) {
    errors <- c(errors, "contains retired metadata-generator header")
  }
  if (grepl("\\buse_cassette\\s*\\(", text, perl = TRUE)) {
    errors <- c(errors, "contains VCR cassette call")
  }
  if (grepl("`[^`\\n]*-[^`\\n]*`\\s*\\(", text, perl = TRUE)) {
    errors <- c(errors, "contains backticked hyphenated function call")
  }
  if (grepl("works without parameters", text, fixed = TRUE)) {
    errors <- c(errors, "contains retired no-parameter test wording")
  }
  if (
    !grepl("\\blocal_mocked_bindings\\s*\\(", text, perl = TRUE) &&
      !grepl("\\bwith_mocked_bindings\\s*\\(", text, perl = TRUE)
  ) {
    errors <- c(errors, "does not mock request helper bindings")
  }

  parse_ok <- tryCatch(
    {
      parse(text = text)
      TRUE
    },
    error = function(e) {
      errors <<- c(errors, paste("parse error:", conditionMessage(e)))
      FALSE
    }
  )

  list(
    file = file,
    valid = length(errors) == 0 && isTRUE(parse_ok),
    errors = errors
  )
}

tg_validate_generated_files <- function(root = ".") {
  files <- tg_list_test_files(root)
  generated <- files[vapply(files, function(path) identical(tg_classify_test_file(path), "generated"), logical(1))]
  validations <- lapply(generated, function(path) {
    tg_validate_generated_text(tg_read_text(path), tg_rel_path(path, root))
  })

  failures <- validations[!vapply(validations, `[[`, logical(1), "valid")]
  list(
    files_checked = length(generated),
    valid = length(failures) == 0,
    failures = failures,
    validations = validations
  )
}

tg_check_generated_tests_current <- function(desired, root = ".") {
  mismatches <- list()

  for (spec in desired) {
    path <- tg_file_path(root, spec$file)
    if (!file.exists(path)) {
      mismatches[[spec$function_name]] <- list(
        function_name = spec$function_name,
        file = spec$file,
        reason = "missing"
      )
      next
    }

    status <- tg_classify_test_file(path)
    if (identical(status, "manual")) {
      next
    }

    if (!tg_generated_text_identical(tg_read_text(path), spec$text)) {
      mismatches[[spec$function_name]] <- list(
        function_name = spec$function_name,
        file = spec$file,
        reason = "out_of_date"
      )
    }
  }

  static <- tg_validate_generated_files(root)
  list(
    current = length(mismatches) == 0 && isTRUE(static$valid),
    mismatches = mismatches,
    static = static
  )
}
