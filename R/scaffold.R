# ==============================================================================
# File Scaffolding
# ==============================================================================

#' Check if a file contains a protected lifecycle badge
#'
#' Scans an R source file for `lifecycle::badge()` calls and returns TRUE if
#' any badge is "stable", "maturing", or "superseded". These indicate the file
#' contains mature code that should not be overwritten by generated stubs.
#'
#' @param path Path to the R source file.
#' @return Logical; TRUE if a protected lifecycle is found, FALSE otherwise.
#' @keywords internal
has_protected_lifecycle <- function(path) {
  protected_statuses <- c("stable", "maturing", "superseded", "deprecated", "defunct")
  lines <- tryCatch(readLines(path, warn = FALSE), error = function(e) character())
  if (length(lines) == 0) {
    return(FALSE)
  }

  # Match lifecycle::badge("status") patterns
  badges <- stringr::str_extract_all(
    lines,
    'lifecycle::badge\\("([^"]+)"\\)'
  )

  statuses <- unlist(badges, use.names = FALSE)
  if (length(statuses) == 0) {
    return(FALSE)
  }

  # Extract just the status string from the badge call
  statuses <- stringr::str_extract(statuses, '(?<=badge\\(")[^"]+')
  any(tolower(statuses) %in% protected_statuses)
}

#' Write generated files to disk based on a specification tibble
#'
#' Creates or updates files according to a data frame describing file paths and their content.
#' The result tibble is returned invisibly, allowing you to capture it for inspection.
#'
#' @param data Data frame or tibble with at least columns for file paths and text.
#' @param path_col Name of the column containing file paths; default "file".
#' @param text_col Name of the column containing the file content; default "text".
#' @param base_dir Base directory to prepend to relative paths.
#' @param overwrite If TRUE, existing files will be overwritten; otherwise they are skipped.
#' @param append If TRUE, text is appended to existing files.
#' @param quiet If FALSE, progress messages are printed.
#' @return A tibble summarising each write operation with columns:
#'   - path: Full file path
#'   - action: What happened (created, skipped, overwritten, appended, error)
#'   - existed: Whether file existed before operation
#'   - written: Whether write succeeded
#'   - size_bytes: File size after operation
#'
#' @examples
#' \dontrun{
#' # Capture result to inspect which files weren't created
#' result <- scaffold_files(spec_with_text, base_dir = "R", overwrite = FALSE)
#'
#' # Check for skipped or failed files
#' result %>% filter(action %in% c("skipped", "error"))
#' }
#' @export
scaffold_files <- function(
  data,
  path_col = "file",
  text_col = "text",
  base_dir = ".",
  overwrite = FALSE,
  append = FALSE,
  quiet = FALSE
) {
  stopifnot(is.data.frame(data))
  if (!requireNamespace("fs", quietly = TRUE)) {
    stop("Package 'fs' is required.")
  }
  if (!requireNamespace("readr", quietly = TRUE)) {
    stop("Package 'readr' is required.")
  }
  if (!requireNamespace("dplyr", quietly = TRUE)) {
    stop("Package 'dplyr' is required.")
  }
  if (!requireNamespace("purrr", quietly = TRUE)) {
    stop("Package 'purrr' is required.")
  }

  if (!path_col %in% names(data)) {
    stop(sprintf("Column '%s' not found in data.", path_col))
  }
  if (!text_col %in% names(data)) {
    stop(sprintf("Column '%s' not found in data.", text_col))
  }

  # Normalize and join paths with base_dir (if relative)
  paths <- purrr::map_chr(data[[path_col]], function(p) {
    if (fs::is_absolute_path(p)) fs::path_norm(p) else fs::path(base_dir, p)
  })

  jobs <- dplyr::tibble(
    index = seq_len(nrow(data)),
    path = paths,
    text = data[[text_col]]
  )

  write_one <- function(index, path, text) {
    # Allow text to be either a scalar string or a list-column of character lines
    if (is.list(text)) {
      text <- unlist(text, recursive = FALSE, use.names = FALSE)
    }

    # Ensure directory exists
    dir_path <- fs::path_dir(path)
    if (!fs::dir_exists(dir_path)) {
      fs::dir_create(dir_path, recurse = TRUE)
    }

    existed <- fs::file_exists(path)

    # --- Lifecycle guard ---
    # Protect stable/maturing/superseded functions from being overwritten
    # by experimental stubs. If an existing file contains a non-experimental
    # lifecycle badge, skip the write entirely.
    if (existed && (overwrite || append)) {
      protected <- has_protected_lifecycle(path)
      if (protected) {
        if (!quiet) {
          cli::cli_alert_warning(
            "Skipping {.path {basename(path)}} — contains stable/maturing/superseded lifecycle"
          )
        }
        return(dplyr::tibble(
          index = index,
          path = path,
          action = "skipped_lifecycle",
          existed = TRUE,
          written = FALSE,
          size_bytes = file.size(path)
        ))
      }
    }

    # Decide whether to skip, append, or write fresh/overwrite
    if (existed && !overwrite && !append) {
      if (!quiet) {
        message(sprintf("Skipping (exists): %s", path))
      }
      return(dplyr::tibble(
        index = index,
        path = path,
        action = "skipped_exists",
        existed = TRUE,
        written = FALSE,
        size_bytes = if (existed) file.size(path) else NA_real_
      ))
    }

    action <- if (append && existed) {
      "appended"
    } else if (existed) {
      "overwritten"
    } else {
      "created"
    }

    out <- tryCatch(
      {
        if (length(text) > 1) {
          readr::write_lines(text, path, append = append)
        } else {
          readr::write_file(as.character(text %||% ""), path, append = append)
        }
        TRUE
      },
      error = function(e) e
    )

    if (isTRUE(out)) {
      if (!quiet) {
        message(sprintf("%s: %s", action, path))
      }
      dplyr::tibble(
        index = index,
        path = path,
        action = action,
        existed = existed,
        written = TRUE,
        size_bytes = file.size(path)
      )
    } else {
      if (!quiet) {
        message(sprintf("Error writing %s: %s", path, out$message))
      }
      dplyr::tibble(
        index = index,
        path = path,
        action = "error",
        existed = existed,
        written = FALSE,
        size_bytes = if (fs::file_exists(path)) file.size(path) else NA_real_
      )
    }
  }

  if (nrow(jobs) == 0) {
    return(dplyr::tibble(
      index = integer(),
      path = character(),
      action = character(),
      existed = logical(),
      written = logical(),
      size_bytes = numeric()
    ))
  }

  result <- purrr::pmap_dfr(jobs, write_one)
  print(result, n = Inf)

  # Return result invisibly so users can inspect which files were/weren't created
  invisible(result)
}
