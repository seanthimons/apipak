# ==============================================================================
# Codebase Analysis
# ==============================================================================

#' Find usages of API endpoints in the package source
#'
#' Scans R source files for endpoint assignments matching the pattern `endpoint = "path"`.
#' This function searches for specific endpoint path values in code where they are
#' assigned to a variable named "endpoint".
#'
#' @param endpoints Character vector of endpoint strings (may contain `{}` placeholders).
#' @param pkg_dir Directory of the package to scan; defaults to current directory.
#' @param ignore_case Logical, whether the search is case‑insensitive.
#' @param files_regex Regex for file extensions to include (e.g., "\\.(R|Rmd|qmd|Rnw|Rd|md)$").
#' @param include_no_leading_slash Logical, also search for path variants without a leading slash
#'   (e.g., both "/alerts" and "alerts"). This helps catch endpoints that may be stored
#'   with or without a leading slash in the code.
#' @param keep_trailing_slash Logical, retain trailing slash in base paths.
#' @param expected_files Optional character vector of expected file names (basenames) for each endpoint.
#'   Must be the same length as `endpoints` if provided. When provided, only hits from files
#'   matching the expected file name are counted as valid implementations. This prevents
#'   false positives when an endpoint is used in a different file (e.g., a wrapper function).
#' @return A list with two elements:
#'   \describe{\item{hits}{data.frame of each match with file, line, text, etc.}\item{summary}{summary data.frame per endpoint.}}
#' @export
find_endpoint_usages_base <- function(
  endpoints,
  pkg_dir = ".",
  ignore_case = TRUE,
  files_regex = "\\.(R|Rmd|qmd|Rnw|Rd|md)$",
  include_no_leading_slash = TRUE,
  keep_trailing_slash = TRUE,
  expected_files = NULL
) {
  # Validate expected_files if provided
  if (!is.null(expected_files) && length(expected_files) != length(endpoints)) {
    stop(sprintf(
      "expected_files must have the same length as endpoints (got %d expected_files for %d endpoints)",
      length(expected_files),
      length(endpoints)
    ))
  }

  base_paths <- strip_curly_params(endpoints, keep_trailing_slash = keep_trailing_slash, leading_slash = 'remove')

  files <- list.files(pkg_dir, pattern = files_regex, recursive = TRUE, full.names = TRUE)

  scan_file <- function(f, pat) {
    lines <- tryCatch(readLines(f, warn = FALSE), error = function(e) character())
    if (!length(lines)) {
      return(NULL)
    }
    # Search for "endpoint = " prefix followed by the pattern
    # This makes the search more specific to endpoint assignments
    search_pattern <- paste0('endpoint\\s*=\\s*"', pat, '"')
    hits <- which(stringr::str_detect(lines, stringr::regex(search_pattern, ignore_case = ignore_case)))
    if (!length(hits)) {
      return(NULL)
    }
    data.frame(
      file = f,
      line = hits,
      text = substr(lines[hits], 1, 240),
      stringsAsFactors = FALSE
    )
  }

  hits_list <- list()
  for (i in seq_along(endpoints)) {
    ep <- endpoints[i]
    bp <- base_paths[i]
    expected_file <- if (!is.null(expected_files)) expected_files[i] else NULL
    # Create pattern variations: with and without leading slash
    pat_set <- unique(c(bp, if (include_no_leading_slash) stringr::str_remove(bp, "^/")))
    for (pat in pat_set) {
      for (f in files) {
        # If expected_file is specified, only check files with matching basename
        if (!is.null(expected_file) && basename(f) != expected_file) {
          next
        }
        h <- scan_file(f, pat)
        if (!is.null(h)) {
          h$endpoint <- ep
          h$base_path <- bp
          h$pattern <- pat
          hits_list[[length(hits_list) + 1]] <- h
        }
      }
    }
  }

  hits <- if (length(hits_list)) {
    do.call(rbind, hits_list)
  } else {
    data.frame(
      file = character(),
      line = integer(),
      text = character(),
      endpoint = character(),
      base_path = character(),
      pattern = character(),
      stringsAsFactors = FALSE
    )
  }

  summarize_ep <- function(ep_df) {
    ep_df <- ep_df[order(ep_df$file, ep_df$line), , drop = FALSE]
    first <- ep_df[1, , drop = FALSE]
    data.frame(
      endpoint = first$endpoint,
      base_path = first$base_path,
      n_hits = nrow(ep_df),
      n_files = length(unique(ep_df$file)),
      first_file = first$file,
      first_line = first$line,
      first_snippet = first$text,
      stringsAsFactors = FALSE
    )
  }

  if (nrow(hits)) {
    by_ep <- split(hits, hits$endpoint, drop = TRUE)
    summary_found <- do.call(rbind, lapply(by_ep, summarize_ep))
  } else {
    summary_found <- data.frame(
      endpoint = character(),
      base_path = character(),
      n_hits = integer(),
      n_files = integer(),
      first_file = character(),
      first_line = integer(),
      first_snippet = character(),
      stringsAsFactors = FALSE
    )
  }

  missing_eps <- setdiff(endpoints, summary_found$endpoint)
  if (length(missing_eps)) {
    summary_missing <- data.frame(
      endpoint = missing_eps,
      base_path = strip_curly_params(
        missing_eps,
        keep_trailing_slash = keep_trailing_slash,
        leading_slash = 'remove'
      ),
      n_hits = 0L,
      n_files = 0L,
      first_file = NA_character_,
      first_line = NA_integer_,
      first_snippet = NA_character_,
      stringsAsFactors = FALSE
    )

    # --- Fallback: file-existence + function-definition check ---
    # When endpoint string matching fails, check if the expected file exists
    # and contains a real function definition (not just a stub placeholder).
    # This catches stable functions that use a different endpoint string format
    # than what the schema generates.
    if (!is.null(expected_files)) {
      ep_to_expected <- setNames(expected_files, endpoints)
      for (i in seq_len(nrow(summary_missing))) {
        ep <- summary_missing$endpoint[i]
        ef <- ep_to_expected[ep]
        if (is.na(ef) || is.null(ef)) {
          next
        }

        candidate <- file.path(pkg_dir, ef)
        if (!file.exists(candidate)) {
          next
        }

        lines <- tryCatch(readLines(candidate, warn = FALSE), error = function(e) character())
        if (length(lines) == 0) {
          next
        }

        # Derive expected function name from the filename (e.g., ct_hazard.R -> ct_hazard)
        fn_name <- tools::file_path_sans_ext(basename(ef))
        # Check for a function definition: fn_name <- function or fn_name = function
        fn_pattern <- paste0("^\\s*", gsub("\\.", "\\\\.", fn_name), "\\s*(<-|=)\\s*function\\b")
        fn_hits <- which(stringr::str_detect(lines, fn_pattern))

        if (length(fn_hits) > 0) {
          summary_missing$n_hits[i] <- 1L
          summary_missing$n_files[i] <- 1L
          summary_missing$first_file[i] <- candidate
          summary_missing$first_line[i] <- fn_hits[1]
          summary_missing$first_snippet[i] <- substr(lines[fn_hits[1]], 1, 240)
        }
      }
    }

    summary <- rbind(summary_found, summary_missing)
  } else {
    summary <- summary_found
  }

  # Keep original order
  summary <- summary[match(endpoints, summary$endpoint), , drop = FALSE]

  list(hits = hits, summary = summary)
}
