empty_scaffold <- function() tibble(action = character(), file = character())

derive_fn_from_file <- function(df, file_col) {
  df %>%
    mutate(.fn_file = .data[[file_col]]) %>%
    group_by(.fn_file) %>%
    mutate(
      .mc = n(),
      .fn = case_when(
        .mc == 1 ~ tools::file_path_sans_ext(basename(.fn_file)),
        method == "GET" ~ tools::file_path_sans_ext(basename(.fn_file)),
        method == "POST" ~ paste0(tools::file_path_sans_ext(basename(.fn_file)), "_bulk"),
        .default = paste0(tools::file_path_sans_ext(basename(.fn_file)), "_", tolower(method))
      )
    ) %>%
    ungroup() %>%
    pull(.fn)
}

resolve_collisions <- function(df) {
  df %>%
    add_count(fn_short, name = "n_short_count") %>%
    mutate(
      file = if_else(n_short_count > 1, file_full, file_short),
      fn = if_else(n_short_count > 1, fn_full, fn_short)
    ) %>%
    select(
      -any_of(c("file_short", "file_full", "fn_short", "fn_full", "n_short_count")),
      -starts_with(".")
    )
}

run_generator <- function(spec, pkg_dir) {
  cli_h2(spec$heading)

  endpoints <- spec$build_endpoints()

  if (is.null(endpoints) || nrow(endpoints) == 0) {
    return(list(scaffold = empty_scaffold(), drift = tibble()))
  }

  if (!is.null(spec$prepare)) {
    spec$prepare(endpoints)
  }

  # Find missing endpoints
  res <- find_endpoint_usages_base(
    endpoints$route,
    pkg_dir = pkg_dir,
    files_regex = sprintf("^%s_.*\\.R$", spec$prefix),
    expected_files = endpoints$file
  )

  # Detect parameter drift for existing endpoints
  drift <- detect_parameter_drift(
    endpoints = endpoints,
    usage_summary = res$summary %>% filter(n_hits > 0),
    pkg_dir = pkg_dir
  )

  endpoints_to_build <- endpoints %>%
    filter(!purrr::map2_lgl(file, fn, is_operation_implemented, pkg_dir = pkg_dir))

  if (nrow(endpoints_to_build) == 0) {
    if (!is.null(spec$finalize)) {
      spec$finalize(endpoints)
    }
    cli_alert_success("All {spec$prefix}_* endpoints already implemented")
    return(list(scaffold = empty_scaffold(), drift = drift))
  }

  cli_alert_info("Found {nrow(endpoints_to_build)} endpoint(s) to generate")

  # Generate stubs
  spec_with_text <- render_endpoint_stubs(endpoints_to_build, config = spec$config)

  # Empty check must precede spec$post(): a zero-row render result has no
  if (nrow(spec_with_text) == 0) {
    if (!is.null(spec$finalize)) {
      spec$finalize(endpoints)
    }
    cli_alert_warning("No {spec$prefix} stubs generated (all skipped)")
    return(list(scaffold = empty_scaffold(), drift = drift))
  }

  if (!is.null(spec$post)) {
    spec_with_text <- spec$post(spec_with_text)
  }

  scaffold <- scaffold_files(
    spec_with_text,
    base_dir = pkg_dir,
    overwrite = FALSE,
    append = TRUE,
    quiet = TRUE
  )
  if (!is.null(spec$finalize)) {
    spec$finalize(endpoints)
  }

  list(scaffold = scaffold, drift = drift)
}

is_operation_implemented <- function(file, fn, pkg_dir) {
  path <- file.path(pkg_dir, file)
  if (!file.exists(path)) {
    return(FALSE)
  }
  lines <- tryCatch(readLines(path, warn = FALSE), error = function(e) character())
  pattern <- sprintf("^\\s*%s\\s*(<-|=)\\s*function\\b", gsub("\\.", "\\\\.", fn))
  any(grepl(pattern, lines))
}

endpoint_coverage <- function(spec, pkg_dir) {
  eps <- spec$build_endpoints()
  if (is.null(eps) || nrow(eps) == 0) {
    return(list(total = 0L, covered = 0L))
  }
  covered <- sum(vapply(
    seq_len(nrow(eps)),
    function(i) is_operation_implemented(eps$file[i], eps$fn[i], pkg_dir),
    logical(1)
  ))
  list(total = nrow(eps), covered = as.integer(covered))
}
