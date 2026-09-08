extract_function_params <- function(file_path, function_name) {
  if (!file.exists(file_path)) {
    return(NULL)
  }

  # Try parse-based approach first (robust for complete files)
  tryCatch(
    {
      parsed <- parse(file = file_path)

      for (i in seq_along(parsed)) {
        expr <- parsed[[i]]
        # Look for: function_name <- function(...)
        if (
          is.call(expr) &&
            as.character(expr[[1]]) == "<-" &&
            is.name(expr[[2]]) &&
            as.character(expr[[2]]) == function_name &&
            is.call(expr[[3]]) &&
            as.character(expr[[3]][[1]]) == "function"
        ) {
          fn_expr <- expr[[3]]
          return(names(formals(eval(fn_expr))))
        }
      }

      # Function not found in parsed expressions
      return(NULL)
    },
    error = function(e) {
      # Parse failed - fall back to regex
      NULL
    }
  )

  # Regex fallback for incomplete/non-parseable files
  tryCatch(
    {
      content <- readLines(file_path, warn = FALSE)

      # Find function definition: function_name <- function(...)
      fn_pattern <- paste0("^\\s*", function_name, "\\s*<-\\s*function\\s*\\(")
      fn_line_idx <- grep(fn_pattern, content)

      if (length(fn_line_idx) == 0) {
        return(NULL)
      }

      # Extract function signature (may span multiple lines)
      start_idx <- fn_line_idx[1]
      sig_text <- content[start_idx]

      # Find matching closing parenthesis
      open_count <- stringr::str_count(sig_text, "\\(")
      close_count <- stringr::str_count(sig_text, "\\)")

      idx <- start_idx
      while (open_count > close_count && idx < length(content)) {
        idx <- idx + 1
        sig_text <- paste(sig_text, content[idx])
        open_count <- open_count + stringr::str_count(content[idx], "\\(")
        close_count <- close_count + stringr::str_count(content[idx], "\\)")
      }

      # Extract parameters from signature
      # Match: function(...params...)
      sig_match <- stringr::str_match(sig_text, "function\\s*\\(([^\\)]*)\\)")
      if (is.na(sig_match[1, 2])) {
        return(character(0)) # No params (function())
      }

      params_str <- sig_match[1, 2]

      # Split by comma and extract parameter names
      params <- strsplit(params_str, ",")[[1]]
      params <- trimws(params)
      params <- params[nzchar(params)]

      # Remove defaults (everything after =)
      params <- gsub("\\s*=\\s*.*$", "", params)
      params <- trimws(params)

      return(params)
    },
    error = function(e) {
      cli::cli_warn(c(
        "!" = "Failed to extract parameters for {.fn {function_name}} in {.file {basename(file_path)}}",
        "i" = "Parse error: {e$message}"
      ))
      return(NULL)
    }
  )
}

detect_parameter_drift <- function(endpoints, usage_summary, pkg_dir = "R") {
  if (!requireNamespace("dplyr", quietly = TRUE)) {
    stop("Package 'dplyr' is required.")
  }
  if (!requireNamespace("purrr", quietly = TRUE)) {
    stop("Package 'purrr' is required.")
  }

  # Filter to implemented endpoints only
  implemented <- usage_summary %>%
    dplyr::filter(n_hits > 0)

  if (nrow(implemented) == 0) {
    return(tibble::tibble(
      endpoint = character(),
      file = character(),
      function_name = character(),
      drift_type = character(),
      param_name = character(),
      schema_value = character(),
      code_value = character()
    ))
  }

  drift_results <- list()

  for (i in seq_len(nrow(implemented))) {
    endpoint_route <- implemented$endpoint[i]
    file_path <- implemented$first_file[i]

    # Find matching endpoint in schema
    endpoint_row <- endpoints %>%
      dplyr::filter(route == endpoint_route) %>%
      dplyr::slice(1)

    if (nrow(endpoint_row) == 0) {
      next # Schema not found for this endpoint (shouldn't happen)
    }

    # Build full path
    full_path <- if (file.path(pkg_dir, file_path) %>% file.exists()) {
      file.path(pkg_dir, file_path)
    } else if (file.path(pkg_dir, file_path) %>% file.exists()) {
      file.path(pkg_dir, file_path)
    } else {
      next # File not found
    }

    # Derive function name from file path
    # Convention: R/ct_hazard_iris.R -> ct_hazard_iris
    function_name <- tools::file_path_sans_ext(basename(file_path))

    # Extract function parameters from source
    code_params <- extract_function_params(full_path, function_name)

    if (is.null(code_params)) {
      # Could not extract params - skip this endpoint
      next
    }

    # Collect schema parameters from all sources
    schema_params <- character()

    # Path parameters
    if (
      !is.null(endpoint_row$path_params) &&
        !is.na(endpoint_row$path_params) &&
        nzchar(endpoint_row$path_params)
    ) {
      path_p <- strsplit(endpoint_row$path_params, ",")[[1]]
      path_p <- trimws(path_p)
      schema_params <- c(schema_params, path_p)
    }

    # Query parameters
    if (
      !is.null(endpoint_row$query_params) &&
        !is.na(endpoint_row$query_params) &&
        nzchar(endpoint_row$query_params)
    ) {
      query_p <- strsplit(endpoint_row$query_params, ",")[[1]]
      query_p <- trimws(query_p)
      schema_params <- c(schema_params, query_p)
    }

    # Body parameters
    if (
      !is.null(endpoint_row$body_params) &&
        !is.na(endpoint_row$body_params) &&
        nzchar(endpoint_row$body_params)
    ) {
      body_p <- strsplit(endpoint_row$body_params, ",")[[1]]
      body_p <- trimws(body_p)
      schema_params <- c(schema_params, body_p)
    }

    schema_params <- unique(schema_params[nzchar(schema_params)])

    # Sanitize schema params (match what the generator would do)
    schema_params_sanitized <- vapply(
      schema_params,
      function(x) {
        if (grepl("^[0-9]", x)) {
          paste0("x", x)
        } else {
          make.names(x)
        }
      },
      character(1),
      USE.NAMES = FALSE
    )

    # Remove framework parameters from code_params
    code_params_filtered <- setdiff(code_params, FRAMEWORK_PARAMS)

    # Detect drifts
    added_in_schema <- setdiff(schema_params_sanitized, code_params_filtered)
    removed_from_schema <- setdiff(
      code_params_filtered,
      schema_params_sanitized
    )

    # Record added parameters
    for (param in added_in_schema) {
      # Find original parameter name (unsanitized)
      orig_idx <- which(schema_params_sanitized == param)[1]
      orig_name <- if (!is.na(orig_idx)) schema_params[orig_idx] else param

      # Get type from metadata if available
      param_type <- "unknown"
      if (
        !is.null(endpoint_row$path_param_metadata[[1]]) &&
          orig_name %in% names(endpoint_row$path_param_metadata[[1]])
      ) {
        param_type <- endpoint_row$path_param_metadata[[1]][[
          orig_name
        ]]$type %||%
          "unknown"
      } else if (
        !is.null(endpoint_row$query_param_metadata[[1]]) &&
          orig_name %in% names(endpoint_row$query_param_metadata[[1]])
      ) {
        param_type <- endpoint_row$query_param_metadata[[1]][[
          orig_name
        ]]$type %||%
          "unknown"
      } else if (
        !is.null(endpoint_row$body_param_metadata[[1]]) &&
          orig_name %in% names(endpoint_row$body_param_metadata[[1]])
      ) {
        param_type <- endpoint_row$body_param_metadata[[1]][[
          orig_name
        ]]$type %||%
          "unknown"
      }

      drift_results <- c(
        drift_results,
        list(tibble::tibble(
          endpoint = endpoint_route,
          file = file_path,
          function_name = function_name,
          drift_type = "param_added",
          param_name = param,
          schema_value = paste0("type: ", param_type),
          code_value = NA_character_
        ))
      )
    }

    # Record removed parameters
    for (param in removed_from_schema) {
      drift_results <- c(
        drift_results,
        list(tibble::tibble(
          endpoint = endpoint_route,
          file = file_path,
          function_name = function_name,
          drift_type = "param_removed",
          param_name = param,
          schema_value = NA_character_,
          code_value = "present in function"
        ))
      )
    }
  }

  if (length(drift_results) == 0) {
    return(tibble::tibble(
      endpoint = character(),
      file = character(),
      function_name = character(),
      drift_type = character(),
      param_name = character(),
      schema_value = character(),
      code_value = character()
    ))
  }

  dplyr::bind_rows(drift_results)
}
