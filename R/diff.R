classify_param_change <- function(old_params, new_params) {
  # Handle empty strings
  old_params <- if (is.na(old_params) || nchar(old_params) == 0) {
    character(0)
  } else {
    strsplit(old_params, ",")[[1]]
  }
  new_params <- if (is.na(new_params) || nchar(new_params) == 0) {
    character(0)
  } else {
    strsplit(new_params, ",")[[1]]
  }

  old_set <- trimws(old_params)
  new_set <- trimws(new_params)

  removed <- setdiff(old_set, new_set)
  added <- setdiff(new_set, old_set)

  if (length(removed) > 0) {
    # Removing params is breaking
    detail <- sprintf("params removed: [%s]", paste(removed, collapse = ", "))
    return(list(breaking = TRUE, detail = detail))
  } else if (length(added) > 0) {
    # Adding params is non-breaking
    detail <- sprintf("params added: [%s]", paste(added, collapse = ", "))
    return(list(breaking = FALSE, detail = detail))
  } else {
    # No change (shouldn't happen, but handle it)
    return(list(breaking = FALSE, detail = "params unchanged"))
  }
}

diff_single_schema <- function(old_path, new_path) {
  # Handle errors gracefully
  tryCatch(
    {
      # Source the openapi parser and its dependencies if not already loaded
      if (!exists("openapi_to_spec")) {
        suppressMessages({
          stop(
            "Supply the client parser and schema selection in the explicit tool context"
          )
          stop(
            "Supply the client parser and schema selection in the explicit tool context"
          )
          stop(
            "Supply the client parser and schema selection in the explicit tool context"
          )
          stop(
            "Supply the client parser and schema selection in the explicit tool context"
          )
        })
      }

      # Parse both schemas
      old_json <- jsonlite::fromJSON(old_path, simplifyVector = FALSE)
      new_json <- jsonlite::fromJSON(new_path, simplifyVector = FALSE)

      old_spec <- suppressMessages(openapi_to_spec(old_json))
      new_spec <- suppressMessages(openapi_to_spec(new_json))

      # Filter out admin/auth/metadata/version endpoints
      if (exists("ENDPOINT_PATTERNS_TO_EXCLUDE")) {
        old_spec <- old_spec %>%
          filter(!stringr::str_detect(route, ENDPOINT_PATTERNS_TO_EXCLUDE))
        new_spec <- new_spec %>%
          filter(!stringr::str_detect(route, ENDPOINT_PATTERNS_TO_EXCLUDE))
      }

      # Create endpoint keys as "{METHOD} {route}"
      old_spec <- old_spec %>%
        mutate(endpoint_key = paste(method, route))
      new_spec <- new_spec %>%
        mutate(endpoint_key = paste(method, route))

      old_keys <- old_spec$endpoint_key
      new_keys <- new_spec$endpoint_key

      # Detect changes
      added_keys <- setdiff(new_keys, old_keys)
      removed_keys <- setdiff(old_keys, new_keys)
      common_keys <- intersect(old_keys, new_keys)

      # Build added tibble
      added <- new_spec %>%
        filter(endpoint_key %in% added_keys) %>%
        select(route, method, summary) %>%
        arrange(route, method)

      # Build removed tibble
      removed <- old_spec %>%
        filter(endpoint_key %in% removed_keys) %>%
        select(route, method, summary) %>%
        arrange(route, method)

      # Build modified tibble
      modified_rows <- list()
      for (key in common_keys) {
        old_row <- old_spec %>% filter(endpoint_key == key)
        new_row <- new_spec %>% filter(endpoint_key == key)

        changes <- list()

        # Compare params
        if (!identical(old_row$params, new_row$params)) {
          param_change <- classify_param_change(old_row$params, new_row$params)
          changes <- c(
            changes,
            list(list(
              type = "params",
              breaking = param_change$breaking,
              detail = param_change$detail
            ))
          )
        }

        # Compare body_params
        if (!identical(old_row$body_params, new_row$body_params)) {
          param_change <- classify_param_change(
            old_row$body_params,
            new_row$body_params
          )
          changes <- c(
            changes,
            list(list(
              type = "body_params",
              breaking = param_change$breaking,
              detail = sprintf("body %s", param_change$detail)
            ))
          )
        }

        # Compare has_body
        if (!identical(old_row$has_body, new_row$has_body)) {
          if (new_row$has_body && !old_row$has_body) {
            changes <- c(
              changes,
              list(list(
                type = "body_added",
                breaking = TRUE,
                detail = "request body added"
              ))
            )
          } else {
            changes <- c(
              changes,
              list(list(
                type = "body_removed",
                breaking = TRUE,
                detail = "request body removed"
              ))
            )
          }
        }

        # Compare deprecated status
        if (!identical(old_row$deprecated, new_row$deprecated)) {
          if (new_row$deprecated && !old_row$deprecated) {
            changes <- c(
              changes,
              list(list(
                type = "deprecated",
                breaking = FALSE,
                detail = "endpoint deprecated"
              ))
            )
          }
        }

        # If any changes detected, add to modified list
        if (length(changes) > 0) {
          for (change in changes) {
            modified_rows <- c(
              modified_rows,
              list(tibble(
                route = new_row$route,
                method = new_row$method,
                change_type = change$type,
                detail = change$detail,
                breaking = change$breaking
              ))
            )
          }
        }
      }

      # Combine modified rows into a tibble
      modified <- if (length(modified_rows) > 0) {
        bind_rows(modified_rows) %>% arrange(route, method)
      } else {
        tibble(
          route = character(),
          method = character(),
          change_type = character(),
          detail = character(),
          breaking = logical()
        )
      }

      list(
        schema_file = basename(new_path),
        added = added,
        removed = removed,
        modified = modified
      )
    },
    error = function(e) {
      list(
        schema_file = basename(new_path),
        error = as.character(e$message)
      )
    }
  )
}

diff_schemas <- function(
  old_dir,
  new_dir,
  pattern = "\\.json$",
  stage_priority = NULL,
  exclude_pattern = NULL
) {
  # Source schema selection utility if using stage priority
  if (!is.null(stage_priority)) {
    if (!exists("select_schema_files")) {
      suppressMessages({
        stop(
          "Supply the client parser and schema selection in the explicit tool context"
        )
      })
    }
  }

  # List files in both directories
  if (!is.null(stage_priority)) {
    # Use select_schema_files to get canonical schemas per domain
    old_files <- select_schema_files(
      pattern = pattern,
      exclude_pattern = exclude_pattern,
      stage_priority = stage_priority,
      schema_dir = old_dir
    )
    new_files <- select_schema_files(
      pattern = pattern,
      exclude_pattern = exclude_pattern,
      stage_priority = stage_priority,
      schema_dir = new_dir
    )
  } else {
    # List all matching files
    old_files <- list.files(old_dir, pattern = pattern, full.names = FALSE)
    new_files <- list.files(new_dir, pattern = pattern, full.names = FALSE)
  }

  all_files <- unique(c(old_files, new_files))

  results <- list()

  for (file in all_files) {
    old_path <- file.path(old_dir, file)
    new_path <- file.path(new_dir, file)

    if (!file.exists(old_path)) {
      # Entire file is new - all endpoints are "added"
      tryCatch(
        {
          if (!exists("openapi_to_spec")) {
            suppressMessages({
              stop(
                "Supply the client parser and schema selection in the explicit tool context"
              )
              stop(
                "Supply the client parser and schema selection in the explicit tool context"
              )
              stop(
                "Supply the client parser and schema selection in the explicit tool context"
              )
              stop(
                "Supply the client parser and schema selection in the explicit tool context"
              )
            })
          }
          new_json <- jsonlite::fromJSON(new_path, simplifyVector = FALSE)
          new_spec <- suppressMessages(openapi_to_spec(new_json))

          # Filter out admin/auth/metadata/version endpoints
          if (exists("ENDPOINT_PATTERNS_TO_EXCLUDE")) {
            new_spec <- new_spec %>%
              filter(!stringr::str_detect(route, ENDPOINT_PATTERNS_TO_EXCLUDE))
          }

          results[[file]] <- list(
            schema_file = file,
            added = new_spec %>% select(route, method, summary),
            removed = tibble(
              route = character(),
              method = character(),
              summary = character()
            ),
            modified = tibble(
              route = character(),
              method = character(),
              change_type = character(),
              detail = character(),
              breaking = logical()
            )
          )
        },
        error = function(e) {
          results[[file]] <<- list(
            schema_file = file,
            error = as.character(e$message)
          )
        }
      )
    } else if (!file.exists(new_path)) {
      # Entire file removed - all endpoints are "removed"
      tryCatch(
        {
          if (!exists("openapi_to_spec")) {
            suppressMessages({
              stop(
                "Supply the client parser and schema selection in the explicit tool context"
              )
              stop(
                "Supply the client parser and schema selection in the explicit tool context"
              )
              stop(
                "Supply the client parser and schema selection in the explicit tool context"
              )
              stop(
                "Supply the client parser and schema selection in the explicit tool context"
              )
            })
          }
          old_json <- jsonlite::fromJSON(old_path, simplifyVector = FALSE)
          old_spec <- suppressMessages(openapi_to_spec(old_json))

          # Filter out admin/auth/metadata/version endpoints
          if (exists("ENDPOINT_PATTERNS_TO_EXCLUDE")) {
            old_spec <- old_spec %>%
              filter(!stringr::str_detect(route, ENDPOINT_PATTERNS_TO_EXCLUDE))
          }

          results[[file]] <- list(
            schema_file = file,
            added = tibble(
              route = character(),
              method = character(),
              summary = character()
            ),
            removed = old_spec %>% select(route, method, summary),
            modified = tibble(
              route = character(),
              method = character(),
              change_type = character(),
              detail = character(),
              breaking = logical()
            )
          )
        },
        error = function(e) {
          results[[file]] <<- list(
            schema_file = file,
            error = as.character(e$message)
          )
        }
      )
    } else {
      # Both exist - run diff
      results[[file]] <- diff_single_schema(old_path, new_path)
    }
  }

  # Filter out schemas with zero changes
  results <- purrr::keep(results, function(r) {
    if (!is.null(r$error)) {
      return(TRUE)
    } # Keep errors
    nrow(r$added) > 0 || nrow(r$removed) > 0 || nrow(r$modified) > 0
  })

  results
}

format_diff_markdown <- function(diff_results) {
  if (length(diff_results) == 0) {
    return("No endpoint-level changes detected.")
  }

  # Aggregate counts
  total_added <- sum(sapply(diff_results, function(r) {
    nrow(r$added %||% tibble())
  }))
  total_removed <- sum(sapply(diff_results, function(r) {
    nrow(r$removed %||% tibble())
  }))
  total_modified <- sum(sapply(diff_results, function(r) {
    nrow(r$modified %||% tibble())
  }))

  # Collect breaking and non-breaking changes
  breaking_changes <- list()
  nonbreaking_changes <- list()

  for (schema_name in names(diff_results)) {
    result <- diff_results[[schema_name]]

    # Handle errors
    if (!is.null(result$error)) {
      breaking_changes <- c(
        breaking_changes,
        list(tibble(
          schema = schema_name,
          endpoint = "ERROR",
          change = "Parse error",
          detail = result$error
        ))
      )
      next
    }

    # Removed endpoints are breaking
    if (nrow(result$removed) > 0) {
      for (i in seq_len(nrow(result$removed))) {
        breaking_changes <- c(
          breaking_changes,
          list(tibble(
            schema = schema_name,
            endpoint = paste(result$removed$method[i], result$removed$route[i]),
            change = "Removed",
            detail = "Endpoint no longer exists"
          ))
        )
      }
    }

    # Added endpoints are non-breaking
    if (nrow(result$added) > 0) {
      for (i in seq_len(nrow(result$added))) {
        nonbreaking_changes <- c(
          nonbreaking_changes,
          list(tibble(
            schema = schema_name,
            endpoint = paste(result$added$method[i], result$added$route[i]),
            change = "Added",
            detail = "New endpoint"
          ))
        )
      }
    }

    # Modified endpoints - classify by breaking flag
    if (nrow(result$modified) > 0) {
      for (i in seq_len(nrow(result$modified))) {
        entry <- tibble(
          schema = schema_name,
          endpoint = paste(result$modified$method[i], result$modified$route[i]),
          change = "Modified",
          detail = result$modified$detail[i]
        )

        if (result$modified$breaking[i]) {
          breaking_changes <- c(breaking_changes, list(entry))
        } else {
          nonbreaking_changes <- c(nonbreaking_changes, list(entry))
        }
      }
    }
  }

  # Build markdown
  md <- character()

  md <- c(md, "### Endpoint Changes\n")
  md <- c(
    md,
    sprintf(
      "**Summary:** %d endpoints added, %d removed, %d modified across %d schemas\n",
      total_added,
      total_removed,
      total_modified,
      length(diff_results)
    )
  )

  # Breaking changes section
  if (length(breaking_changes) > 0) {
    md <- c(md, "\n#### Breaking Changes\n")
    md <- c(md, "| Schema | Endpoint | Change | Detail |")
    md <- c(md, "|--------|----------|--------|--------|")

    breaking_df <- bind_rows(breaking_changes)
    for (i in seq_len(nrow(breaking_df))) {
      md <- c(
        md,
        sprintf(
          "| %s | %s | %s | %s |",
          breaking_df$schema[i],
          breaking_df$endpoint[i],
          breaking_df$change[i],
          breaking_df$detail[i]
        )
      )
    }
  }

  # Non-breaking changes section
  if (length(nonbreaking_changes) > 0) {
    md <- c(md, "\n#### Non-Breaking Changes\n")
    md <- c(md, "| Schema | Endpoint | Change | Detail |")
    md <- c(md, "|--------|----------|--------|--------|")

    nonbreaking_df <- bind_rows(nonbreaking_changes)
    for (i in seq_len(nrow(nonbreaking_df))) {
      md <- c(
        md,
        sprintf(
          "| %s | %s | %s | %s |",
          nonbreaking_df$schema[i],
          nonbreaking_df$endpoint[i],
          nonbreaking_df$change[i],
          nonbreaking_df$detail[i]
        )
      )
    }
  }

  paste(md, collapse = "\n")
}

count_diff_changes <- function(diff_results) {
  breaking <- 0L
  nonbreaking <- 0L
  for (result in diff_results) {
    if (!is.null(result$error)) {
      # Parse error - treat as a breaking change so it surfaces for review
      breaking <- breaking + 1L
      next
    }
    breaking <- breaking + nrow(result$removed)
    nonbreaking <- nonbreaking + nrow(result$added)
    if (nrow(result$modified) > 0) {
      breaking <- breaking + sum(result$modified$breaking)
      nonbreaking <- nonbreaking + sum(!result$modified$breaking)
    }
  }
  list(breaking = as.integer(breaking), nonbreaking = as.integer(nonbreaking))
}
