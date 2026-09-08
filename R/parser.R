sanitize_name <- function(x) {
  x <- stringr::str_replace_all(x, "[^A-Za-z0-9_]", "_")
  x <- stringr::str_replace_all(x, "_+", "_")
  x <- stringr::str_trim(x)
  x
}

method_path_name <- function(route, method) {
  p <- gsub("^/|/$", "", route)
  p <- gsub("\\{([^}]+)\\}", "by_\\1", p)
  p <- gsub("[^A-Za-z0-9]+", "_", p)
  p <- gsub("_+", "_", p)
  tolower(paste0(method, "_", p))
}

dedup_params <- function(params) {
  if (!length(params)) {
    return(list())
  }
  keys <- purrr::map_chr(
    params,
    ~ paste(.x[["name"]] %||% "", .x[["in"]] %||% "", sep = "@")
  )
  params[!duplicated(keys)]
}

param_names <- function(params, where, exclude_pattern = "^files\\[\\]$") {
  purrr::map_chr(
    purrr::keep(
      params,
      ~ identical(.x[["in"]], where) &&
        !grepl(exclude_pattern, .x[["name"]] %||% "")
    ),
    ~ .x[["name"]] %||% ""
  ) -> nm
  nm[nzchar(nm)]
}

param_metadata <- function(params, where, exclude_pattern = "^files\\[\\]$") {
  relevant_params <- purrr::keep(
    params,
    ~ identical(.x[["in"]], where) &&
      !grepl(exclude_pattern, .x[["name"]] %||% "")
  )
  if (length(relevant_params) == 0) {
    return(list())
  }

  metadata <- purrr::map(relevant_params, function(p) {
    schema <- p[["schema"]] %||% list()

    list(
      name = p[["name"]] %||% "",
      example = p[["example"]] %||% schema[["default"]] %||% NA, # Fallback to default
      description = p[["description"]] %||% schema[["description"]] %||% "", # Check schema too
      default = schema[["default"]] %||% NA, # Explicit default field
      enum = schema[["enum"]] %||% NULL, # Allowed values
      type = schema[["type"]] %||% NA, # Data type
      required = p[["required"]] %||% FALSE # Required status
    )
  })

  # Filter out params with no name
  metadata <- purrr::keep(metadata, ~ nzchar(.x$name))

  # Convert to named list for easier lookup
  names(metadata) <- purrr::map_chr(metadata, ~ .x$name)
  metadata
}

get_response_schema_type <- function(responses, openapi_spec) {
  if (is.null(responses) || !is.list(responses)) {
    return("unknown")
  }

  # Look for successful response codes
  success_codes <- intersect(
    names(responses),
    c("200", "201", "202", "204", "default")
  )
  if (length(success_codes) == 0) {
    return("unknown")
  }

  # Check first successful response
  resp <- responses[[success_codes[1]]]
  content <- resp$content %||% list()

  # Check for binary/image content types first
  if (
    any(grepl("^image/", names(content))) ||
      any(grepl("octet-stream", names(content)))
  ) {
    return("binary")
  }

  # Check application/json response
  json_schema <- content[["application/json"]]$schema %||% list()

  # If no JSON schema, return unknown
  if (length(json_schema) == 0) {
    return("unknown")
  }

  # Check for $ref - need to resolve it
  if (!is.null(json_schema[["$ref"]])) {
    ref <- json_schema[["$ref"]]
    ref_parts <- strsplit(ref, "/", fixed = TRUE)[[1]]
    if (
      length(ref_parts) >= 4 &&
        ref_parts[2] == "components" &&
        ref_parts[3] == "schemas"
    ) {
      schema_name <- ref_parts[4]
      components <- openapi_spec[["components"]] %||% list()
      schemas <- components[["schemas"]] %||% list()
      json_schema <- schemas[[schema_name]] %||% list()
    }
  }

  # Determine type from schema
  schema_type <- json_schema[["type"]] %||% ""

  if (schema_type == "array") {
    return("array")
  }
  if (schema_type == "object") {
    return("object")
  }
  if (schema_type %in% c("string", "number", "integer", "boolean")) {
    return("scalar")
  }

  # Default to unknown
  return("unknown")
}

extract_body_schema_metadata <- function(request_body, openapi_spec) {
  if (is.null(request_body) || !is.list(request_body)) {
    return(list())
  }

  # Navigate: requestBody -> content -> application/json -> schema -> $ref
  content <- request_body[["content"]] %||% list()
  json_schema <- content[["application/json"]][["schema"]] %||% list()

  # Check if this is a schema reference
  ref <- json_schema[["$ref"]]
  if (is.null(ref) || !nzchar(ref)) {
    return(list())
  }

  # Parse the reference (e.g., "#/components/schemas/LookupRequest")
  # Format: #/components/schemas/{SchemaName}
  ref_parts <- strsplit(ref, "/", fixed = TRUE)[[1]]
  if (
    length(ref_parts) < 4 ||
      ref_parts[2] != "components" ||
      ref_parts[3] != "schemas"
  ) {
    return(list())
  }

  schema_name <- ref_parts[4]

  # Resolve the schema from components
  components <- openapi_spec[["components"]] %||% list()
  schemas <- components[["schemas"]] %||% list()
  schema_def <- schemas[[schema_name]]

  if (is.null(schema_def) || !is.list(schema_def)) {
    return(list())
  }

  # Extract properties
  properties <- schema_def[["properties"]] %||% list()
  required_fields <- schema_def[["required"]] %||% character(0)

  # Build metadata for each property
  metadata <- purrr::imap(properties, function(prop, prop_name) {
    list(
      name = prop_name,
      description = prop[["description"]] %||% "",
      type = prop[["type"]] %||% NA,
      enum = prop[["enum"]] %||% NULL,
      default = prop[["default"]] %||% NA,
      required = prop_name %in% required_fields,
      example = prop[["example"]] %||% prop[["default"]] %||% NA
    )
  })

  # Filter and return as named list
  metadata <- purrr::keep(metadata, ~ nzchar(.x$name))
  names(metadata) <- purrr::map_chr(metadata, ~ .x$name)
  metadata
}

order_path_by_route <- function(path_names, route) {
  if (!length(path_names)) {
    return(character(0))
  }
  m <- stringr::str_match_all(route, "\\{([^}]+)\\}")
  if (length(m) >= 1 && length(m[[1]]) && nrow(m[[1]]) > 0) {
    unique(m[[1]][, 2])
  } else {
    unique(path_names)
  }
}

detect_pagination <- function(
  route,
  path_params,
  query_params,
  body_params,
  registry = PAGINATION_REGISTRY
) {
  # Split comma-separated param strings into character vectors
  split_params <- function(x) {
    if (is.null(x) || !nzchar(x)) {
      return(character(0))
    }
    trimws(strsplit(x, ",")[[1]])
  }

  path_vec <- split_params(path_params)
  query_vec <- split_params(query_params)
  body_vec <- split_params(body_params)

  for (entry_name in names(registry)) {
    entry <- registry[[entry_name]]

    # If route_pattern is specified, check route first
    if (!is.null(entry$route_pattern)) {
      if (!stringr::str_detect(route, entry$route_pattern)) {
        next
      }
    }

    # AMOS keyset cursors are query parameters for GET and body fields for POST.
    if (identical(entry$strategy, "cursor")) {
      cursor_location <- if ("cursor" %in% query_vec) {
        "query"
      } else if ("cursor" %in% body_vec) {
        "body"
      } else {
        NA_character_
      }
      if ("limit" %in% path_vec && !is.na(cursor_location)) {
        return(list(
          strategy = entry$strategy,
          registry_key = entry_name,
          params = entry$param_names,
          param_location = entry$param_location,
          cursor_location = cursor_location,
          description = entry$description
        ))
      }
      next
    }

    # Match based on param_location
    location <- entry$param_location
    matched <- FALSE

    if (identical(location, "path")) {
      matched <- all(entry$param_names %in% path_vec)
    } else if (identical(location, "query")) {
      matched <- all(entry$param_names %in% query_vec)
    } else if (identical(location, "body")) {
      matched <- all(entry$param_names %in% body_vec)
    }

    if (matched) {
      return(list(
        strategy = entry$strategy,
        registry_key = entry_name,
        params = entry$param_names,
        param_location = entry$param_location,
        cursor_location = NA_character_,
        description = entry$description
      ))
    }
  }

  # No match found - check if params resemble pagination
  pagination_like_params <- c(
    "page",
    "pageNumber",
    "pageSize",
    "offset",
    "limit",
    "size",
    "cursor",
    "itemsPerPage",
    "skip",
    "top",
    "after",
    "before",
    "startIndex",
    "count"
  )

  all_params <- c(path_vec, query_vec, body_vec)
  suspicious <- intersect(all_params, pagination_like_params)

  if (length(suspicious) > 0) {
    cli::cli_warn(c(
      "Parameters resemble pagination but no registry pattern matched.",
      "i" = "Route: {.val {route}}",
      "i" = "Suspicious params: {.val {suspicious}}",
      "i" = "Consider adding a new entry to PAGINATION_REGISTRY in 00_config.R"
    ))
  }

  list(
    strategy = "none",
    registry_key = NA_character_,
    params = character(0),
    param_location = NA_character_,
    cursor_location = NA_character_,
    description = "No pagination detected"
  )
}

openapi_to_spec <- function(
  openapi,
  default_base_url = NULL,
  name_strategy = c("operationId", "method_path"),
  preprocess = TRUE
) {
  if (!requireNamespace("purrr", quietly = TRUE)) {
    stop("Package 'purrr' is required.")
  }
  if (!requireNamespace("tibble", quietly = TRUE)) {
    stop("Package 'tibble' is required.")
  }
  if (!requireNamespace("stringr", quietly = TRUE)) {
    stop("Package 'stringr' is required.")
  }

  name_strategy <- match.arg(name_strategy)

  # Preprocess schema if requested
  if (preprocess && is.character(openapi) && file.exists(openapi)) {
    openapi <- preprocess_schema(openapi)
  }

  # Detect schema version (Swagger 2.0 vs OpenAPI 3.0)
  schema_version <- detect_schema_version(openapi)
  cli::cli_alert_info(
    "Detected schema version: {schema_version$type} {schema_version$version}"
  )

  # Get schema definitions/components based on version
  # Swagger 2.0 uses "definitions", OpenAPI 3.0 uses "components/schemas"
  if (identical(schema_version$type, "swagger")) {
    definitions <- openapi[["definitions"]] %||% list()
    # For Swagger 2.0, we'll pass definitions to body extraction
    components <- list(schemas = definitions) # Normalize for resolve_schema_ref compatibility
  } else {
    definitions <- NULL
    components <- openapi[["components"]] %||% list()
  }

  base_url <- default_base_url %||%
    {
      srv <- openapi$servers
      if (is.list(srv) && length(srv) && !is.null(srv[[1]]$url)) {
        srv[[1]]$url
      } else {
        "https://example.com"
      }
    }

  paths <- openapi$paths
  if (!is.list(paths) || !length(paths)) {
    stop("OpenAPI object has no 'paths'.")
  }

  purrr::imap_dfr(paths, function(path_item, route) {
    path_level_params <- path_item$parameters %||% list()
    # only support GET and POST, so OPTIONS/PUT/PATCH/DELETE endpoints can never
    # be wrapped. Dropping them here keeps stub generation, schema diffs, and
    # coverage counts consistent.
    meths <- intersect(names(path_item), supported_methods)

    purrr::map_dfr(meths, function(method) {
      op <- path_item[[method]]
      op_params <- op$parameters %||% list()
      parameters <- dedup_params(c(path_level_params, op_params))

      path_names <- order_path_by_route(param_names(parameters, "path"), route)

      # Extract query parameters with $ref resolution
      components <- openapi[["components"]] %||% list()
      query_result <- extract_query_params_with_refs(
        parameters,
        components,
        schema_version
      )
      query_names <- query_result$names # Use resolved/flattened parameter names
      query_meta <- query_result$metadata # Use enhanced metadata from resolved schemas

      # Extract parameter metadata (examples and descriptions)
      path_meta <- param_metadata(parameters, "path")

      # Extract request body schema metadata for POST/PUT/PATCH
      body_props <- if (method %in% c("post", "put", "patch")) {
        if (identical(schema_version$type, "swagger")) {
          # Swagger 2.0: body is in parameters array, resolve against definitions
          extract_body_properties(
            op$parameters,
            definitions,
            schema_version = schema_version
          )
        } else {
          # OpenAPI 3.0: body is in requestBody object
          extract_body_properties(op$requestBody, components)
        }
      } else {
        list(type = "unknown", properties = list())
      }

      # Extract body parameter names (ordered by required first, then alphabetically)
      body_names <- if (
        body_props$type %in%
          c("object", "one_of") &&
          length(body_props$properties) > 0
      ) {
        required_names <- names(purrr::keep(
          body_props$properties,
          ~ .x$required
        ))
        optional_names <- names(purrr::keep(
          body_props$properties,
          ~ !.x$required
        ))
        c(required_names, optional_names)
      } else if (
        body_props$type %in%
          c("array", "object_array") &&
          !is.null(body_props$item_schema)
      ) {
        # For array bodies with object items (ref or inline), extract object properties
        item_properties <- body_props$item_schema$properties
        if (length(item_properties) > 0) {
          required_names <- names(purrr::keep(item_properties, ~ .x$required))
          optional_names <- names(purrr::keep(item_properties, ~ !.x$required))
          c(required_names, optional_names)
        } else {
          character(0)
        }
      } else if (
        body_props$type %in%
          c("string", "string_array") &&
          length(body_props$properties) > 0
      ) {
        # Simple body types (string or string_array) - extract synthetic parameter names
        names(body_props$properties)
      } else {
        character(0)
      }

      # Create simplified body_meta for backward compatibility
      body_meta <- if (length(body_names) > 0) {
        purrr::map(body_names, function(name) {
          if (body_props$type %in% c("object", "one_of")) {
            body_props$properties[[name]]
          } else if (
            body_props$type %in%
              c("array", "object_array") &&
              !is.null(body_props$item_schema)
          ) {
            body_props$item_schema$properties[[name]]
          } else if (body_props$type %in% c("string", "string_array")) {
            # Simple body types - use the synthetic parameter metadata
            body_props$properties[[name]]
          } else {
            list(
              name = name,
              type = NA,
              description = "",
              enum = NULL,
              default = NA,
              required = FALSE,
              example = NA
            )
          }
        })
      } else {
        list()
      }
      names(body_meta) <- body_names

      # Combine all parameters (path parameters first, then query parameters)
      combined <- c(path_names, query_names)

      # Detect if endpoint has request body
      has_body <- if (identical(schema_version$type, "swagger")) {
        # Swagger 2.0: check for body parameter in parameters array
        any(purrr::map_lgl(
          op$parameters %||% list(),
          ~ identical(.x[["in"]], "body")
        ))
      } else {
        # OpenAPI 3.0: check for requestBody object
        !is.null(op$requestBody)
      }
      operationId <- op$operationId %||% paste(method, route)
      summary <- op$summary %||% ""

      # Extract deprecated status
      deprecated <- op$deprecated %||% FALSE

      # Extract description for enhanced documentation
      description <- op$description %||% ""

      needs_resolver <- if (method %in% c("post", "put", "patch") && has_body) {
        if (identical(schema_version$type, "swagger")) {
          FALSE
        } else {
          body_requires_resolution(op$requestBody, openapi)
        }
      } else {
        FALSE
      }

      # Get body schema type for more specific code generation
      body_schema_type <- if (
        method %in% c("post", "put", "patch") && has_body
      ) {
        if (identical(schema_version$type, "swagger")) {
          # Use the type from body_props which was already extracted
          body_props$type %||% "unknown"
        } else {
          if (isTRUE(body_props$type %in% c("one_of", "unsupported_map"))) {
            body_props$type
          } else {
            get_body_schema_type(op$requestBody, openapi)
          }
        }
      } else {
        "unknown"
      }

      # Detect response schema type for enhanced documentation
      response_schema_type <- get_response_schema_type(op$responses, openapi)

      # Extract response content types
      response_content_types <- character(0)
      if (!is.null(op$responses)) {
        # Look for successful responses (200, 201, etc.)
        success_codes <- intersect(
          names(op$responses),
          c("200", "201", "202", "204", "default")
        )
        for (code in success_codes) {
          resp <- op$responses[[code]]
          if (!is.null(resp$content) && is.list(resp$content)) {
            response_content_types <- c(
              response_content_types,
              names(resp$content)
            )
          }
        }
      }
      response_content_types <- unique(response_content_types)
      content_type <- if (length(response_content_types) > 0) {
        paste(response_content_types, collapse = ", ")
      } else {
        ""
      }

      # Detect pagination strategy (PAG-01, PAG-03)
      pagination_info <- detect_pagination(
        route = route,
        path_params = if (length(path_names) > 0) {
          paste(path_names, collapse = ",")
        } else {
          ""
        },
        query_params = if (length(query_names) > 0) {
          paste(query_names, collapse = ",")
        } else {
          ""
        },
        body_params = if (length(body_names) > 0) {
          paste(body_names, collapse = ",")
        } else {
          ""
        }
      )

      fn <- if (name_strategy == "operationId") {
        sanitize_name(operationId)
      } else {
        sanitize_name(method_path_name(route, method))
      }

      tibble::tibble(
        route = route,
        method = toupper(method),
        summary = summary,
        has_body = has_body,
        params = if (length(combined) > 0) {
          paste(combined, collapse = ",")
        } else {
          ""
        },
        # Separate path and query parameters for flexible stub generation
        path_params = if (length(path_names) > 0) {
          paste(path_names, collapse = ",")
        } else {
          ""
        },
        query_params = if (length(query_names) > 0) {
          paste(query_names, collapse = ",")
        } else {
          ""
        },
        body_params = if (length(body_names) > 0) {
          paste(body_names, collapse = ",")
        } else {
          ""
        },
        num_path_params = length(path_names),
        num_body_params = length(body_names),
        # Parameter metadata with examples and descriptions
        path_param_metadata = list(path_meta),
        query_param_metadata = list(query_meta),
        body_param_metadata = list(body_meta),
        # Response content type(s)
        content_type = content_type,
        needs_resolver = needs_resolver,
        body_schema_type = body_schema_type,
        # Deprecated status and description
        deprecated = deprecated,
        description = description,
        # Response schema type for enhanced documentation
        response_schema_type = response_schema_type,
        # NEW: Schema type classification
        # - "json": POST/PUT/PATCH with request body
        # - "path": GET with path parameters (appends to URL)
        # - "query_only": GET without path parameters (static endpoint, params via query string)
        # NOTE: method is already uppercased at this point, so compare with uppercase
        request_type = if (
          toupper(method) %in% c("POST", "PUT", "PATCH") && has_body
        ) {
          "json"
        } else if (length(path_names) > 0) {
          "path"
        } else {
          "query_only"
        },
        # NEW: Body schema full information
        body_schema_full = list(body_props),
        # NEW: Body item type for array schemas
        body_item_type = if (!is.null(body_props$item_type)) {
          body_props$item_type
        } else if (!is.null(body_props$item_schema)) {
          body_props$item_schema$ref_type
        } else {
          NA
        },
        # Pagination detection (Phase 19)
        pagination_strategy = pagination_info$strategy,
        pagination_metadata = list(pagination_info)
      )
    })
  })
}
