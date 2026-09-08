`%tg||%` <- function(x, y) {
  if (is.null(x)) {
    y
  } else {
    x
  }
}

tg_norm_path <- function(path) {
  normalizePath(path, winslash = "/", mustWork = FALSE)
}

tg_rel_path <- function(path, root = ".") {
  root <- tg_norm_path(root)
  path <- tg_norm_path(path)
  sub(
    paste0("^", gsub("([][{}()+*^$|\\\\.?])", "\\\\\\1", root), "/?"),
    "",
    path,
    perl = TRUE
  )
}

tg_file_path <- function(root, ...) {
  file.path(root, ...)
}

tg_read_lines <- function(path) {
  if (!file.exists(path)) {
    return(character(0))
  }
  readLines(path, warn = FALSE)
}

tg_read_text <- function(path) {
  paste(tg_read_lines(path), collapse = "\n")
}

tg_without_terminal_newline <- function(text) {
  sub("\\n\\z", "", text, perl = TRUE)
}

tg_canonical_r_code <- function(text) {
  parsed <- tryCatch(
    parse(text = text, keep.source = FALSE),
    error = function(e) NULL
  )
  if (is.null(parsed)) {
    return(NULL)
  }

  paste(
    vapply(
      parsed,
      function(expr) paste(deparse(expr, width.cutoff = 500), collapse = "\n"),
      character(1)
    ),
    collapse = "\n"
  )
}

tg_generated_text_identical <- function(current, expected) {
  if (xor(endsWith(current, "\n"), endsWith(expected, "\n"))) {
    return(FALSE)
  }

  current <- tg_without_terminal_newline(current)
  expected <- tg_without_terminal_newline(expected)

  if (identical(current, expected)) {
    return(TRUE)
  }

  current_code <- tg_canonical_r_code(current)
  expected_code <- tg_canonical_r_code(expected)

  !is.null(current_code) && identical(current_code, expected_code)
}

tg_text_header_lines <- function(text, n = 5L) {
  lines <- strsplit(text, "\n", fixed = TRUE)[[1]]
  if (length(lines) == 0) {
    return(character(0))
  }
  lines[seq_len(min(n, length(lines)))]
}

tg_has_generated_header <- function(text) {
  tg_config$generated_header %in% tg_text_header_lines(text)
}

tg_has_legacy_metadata_header <- function(text) {
  tg_config$legacy_metadata_header %in% tg_text_header_lines(text)
}

tg_test_file_for <- function(function_name, root = ".") {
  tg_file_path(root, tg_config$test_dir, paste0("test-", function_name, ".R"))
}

tg_cli_info <- function(...) {
  if (requireNamespace("cli", quietly = TRUE)) {
    cli::cli_alert_info(...)
  } else {
    message(sprintf(...))
  }
}

tg_cli_success <- function(...) {
  if (requireNamespace("cli", quietly = TRUE)) {
    cli::cli_alert_success(...)
  } else {
    message(sprintf(...))
  }
}

tg_cli_warning <- function(...) {
  if (requireNamespace("cli", quietly = TRUE)) {
    cli::cli_alert_warning(...)
  } else {
    warning(sprintf(...), call. = FALSE)
  }
}

tg_cli_abort <- function(message) {
  if (requireNamespace("cli", quietly = TRUE)) {
    cli::cli_abort(message)
  } else {
    stop(paste(unlist(message), collapse = "\n"), call. = FALSE)
  }
}
