# ==============================================================================
# Schema Preprocessing & Resolution
# ==============================================================================

# Track circular references during resolution

# Extract all schema references from paths
extract_referenced_schemas <- function(paths) {
  refs <- character(0)

  for (route in names(paths)) {
    path_item <- paths[[route]]

    for (method in intersect(
      names(path_item),
      c("get", "post", "put", "patch", "delete", "head", "options", "trace")
    )) {
      op <- path_item[[method]]

      # Extract from requestBody
      if (!is.null(op$requestBody) && is.list(op$requestBody)) {
        content <- op$requestBody[["content"]] %||% list()
        json_schema <- content[["application/json"]][["schema"]] %||% list()
        if (!is.null(json_schema[["$ref"]])) {
          ref <- json_schema[["$ref"]]
          schema_name <- stringr::str_replace(ref, "#/components/schemas/", "")
          refs <- c(refs, schema_name)
        }
      }
    }
  }

  unique(refs)
}

# Filter components to keep only referenced schemas
filter_components_by_refs <- function(components, refs) {
  schemas <- components[["schemas"]] %||% list()

  # Keep only schemas that match refs
  keep_schemas <- intersect(names(schemas), refs)

  # Update components
  components$schemas <- schemas[keep_schemas]
  components
}

# Preprocess OpenAPI schema
# Filters out unwanted endpoints but keeps all schema components intact
preprocess_schema <- function(schema_file, exclude_endpoints = character()) {
  # Load schema
  openapi <- read_schema_document(schema_file)

  # Filter out unwanted endpoints (preflight, health checks, etc.)
  paths <- openapi$paths
  if (!is.null(paths) && length(paths) > 0 && length(exclude_endpoints) > 0) {
    keep_paths <- names(paths)[
      !stringr::str_detect(names(paths), exclude_endpoints)
    ]
    openapi$paths <- paths[keep_paths]
  }

  # Keep all components/definitions intact - aggressive filtering caused

  # regression issues with nested references (e.g., array items, response schemas)
  # that weren't caught by extract_referenced_schemas()

  openapi
}

# Validate schema reference format
# Returns TRUE if valid, aborts with cli::cli_abort() if invalid
validate_schema_ref <- function(ref, endpoint_context = NULL) {
  # Must be a non-empty string
  if (!is.character(ref) || !nzchar(ref)) {
    cli::cli_abort(c(
      "x" = "Invalid schema reference: empty or non-character",
      "i" = if (!is.null(endpoint_context)) {
        paste0(
          "Endpoint: ",
          endpoint_context$method,
          " ",
          endpoint_context$route
        )
      } else {
        NULL
      }
    ))
  }

  # Must start with #/ (internal reference)
  if (!grepl("^#/", ref)) {
    cli::cli_abort(c(
      "x" = "Invalid reference format: {.val {ref}}",
      "i" = "References must start with {.code #/}",
      "i" = "External file references are not supported",
      "i" = if (!is.null(endpoint_context)) {
        paste0(
          "Endpoint: ",
          endpoint_context$method,
          " ",
          endpoint_context$route
        )
      } else {
        NULL
      }
    ))
  }

  # Check for external file refs (not supported)
  if (grepl("\\.(json|yaml|yml)#", ref)) {
    cli::cli_abort(c(
      "x" = "External file reference not supported: {.val {ref}}",
      "i" = "All schemas must be in single file",
      "i" = if (!is.null(endpoint_context)) {
        paste0(
          "Endpoint: ",
          endpoint_context$method,
          " ",
          endpoint_context$route
        )
      } else {
        NULL
      }
    ))
  }

  # Check for valid path prefixes
  valid_prefixes <- c("#/components/schemas/", "#/definitions/")
  has_valid_prefix <- any(purrr::map_lgl(
    valid_prefixes,
    ~ grepl(paste0("^", .x), ref)
  ))

  if (!has_valid_prefix) {
    cli::cli_warn(c(
      "!" = "Unusual reference path: {.val {ref}}",
      "i" = "Expected {.code #/components/schemas/} or {.code #/definitions/}",
      "i" = "Proceeding with caution"
    ))
  }

  # Extract and validate schema name
  schema_name <- stringr::str_replace(
    ref,
    "^#/(components/schemas|definitions)/",
    ""
  )
  if (!nzchar(schema_name)) {
    cli::cli_abort(c(
      "x" = "Missing schema name in reference: {.val {ref}}",
      "i" = "Reference path is incomplete (trailing slash only)",
      "i" = if (!is.null(endpoint_context)) {
        paste0(
          "Endpoint: ",
          endpoint_context$method,
          " ",
          endpoint_context$route
        )
      } else {
        NULL
      }
    ))
  }

  TRUE
}

# Resolve schema reference to actual schema definition
# Enhanced with version-aware fallback chain (REF-01), version context (REF-02), and depth limit 3 (REF-03)
resolve_schema_ref <- function(
  schema_ref,
  components,
  schema_version = NULL,
  max_depth = 3,
  depth = 0,
  endpoint_context = NULL
) {
  # If schema_ref is actual schema (not a reference), just return it
  if (!is.character(schema_ref)) {
    return(schema_ref)
  }

  # Validate reference format
  validate_schema_ref(schema_ref, endpoint_context)

  # Check depth limit (REF-03)
  if (depth > max_depth) {
    cli::cli_abort(c(
      "x" = "Reference depth limit exceeded: {.val {max_depth}}",
      "i" = "Current reference: {.val {schema_ref}}",
      "i" = "This may indicate circular references or overly complex schema",
      "i" = if (!is.null(endpoint_context)) {
        paste0(
          "Endpoint: ",
          endpoint_context$method,
          " ",
          endpoint_context$route
        )
      } else {
        NULL
      }
    ))
  }

  # Sanitize ref_key for use as variable name in R environment
  sanitized_key <- gsub("[^a-zA-Z0-9]", "_", schema_ref)

  # Check for circular reference - only error if we're going DEEPER
  if (exists(sanitized_key, envir = resolve_stack)) {
    existing_depth <- get(sanitized_key, envir = resolve_stack)
    if (depth > existing_depth) {
      cli::cli_warn(c(
        "!" = "Circular reference detected: {.val {schema_ref}}",
        "i" = "Current depth: {depth}, Previous depth: {existing_depth}",
        "i" = "Returning partial schema"
      ))
      return(list(type = "circular_ref", ref = schema_ref))
    }
  }

  # Track reference for cleanup on exit
  assign(sanitized_key, depth, envir = resolve_stack)
  on.exit(
    {
      if (exists(sanitized_key, envir = resolve_stack)) {
        rm(list = sanitized_key, envir = resolve_stack)
      }
    },
    add = TRUE
  )

  # Determine primary and secondary paths based on version (REF-01)
  if (!is.null(schema_version) && identical(schema_version$type, "swagger")) {
    # Swagger 2.0: definitions first, then components
    primary_path <- "#/definitions/"
    secondary_path <- "#/components/schemas/"
    # For Swagger 2.0, components may be normalized definitions (from 07-02)
    primary_container <- components # May be definitions directly or components$schemas
    secondary_container <- components[["schemas"]] %||% list()
  } else {
    # OpenAPI 3.0 or unknown: components first, then definitions
    primary_path <- "#/components/schemas/"
    secondary_path <- "#/definitions/"
    primary_container <- components[["schemas"]] %||% list()
    secondary_container <- components # May have definitions at root
  }

  # Extract schema name from reference
  schema_name <- NULL
  if (grepl(paste0("^", gsub("/", "\\\\/", primary_path)), schema_ref)) {
    schema_name <- stringr::str_replace(
      schema_ref,
      paste0("^", primary_path),
      ""
    )
  } else if (
    grepl(paste0("^", gsub("/", "\\\\/", secondary_path)), schema_ref)
  ) {
    schema_name <- stringr::str_replace(
      schema_ref,
      paste0("^", secondary_path),
      ""
    )
  } else {
    # Unusual path - try extracting from either known prefix
    schema_name <- stringr::str_replace(
      schema_ref,
      "^#/(components/schemas|definitions)/",
      ""
    )
  }

  # Try primary location
  schema_def <- NULL
  if (!is.null(schema_name) && nzchar(schema_name)) {
    schema_def <- primary_container[[schema_name]]
  }

  # Try secondary location (fallback)
  if (is.null(schema_def) || !is.list(schema_def)) {
    fallback_def <- secondary_container[[schema_name]]
    if (!is.null(fallback_def) && is.list(fallback_def)) {
      # Log fallback usage (always, not just verbose)
      cli::cli_alert_info(c(
        "Reference resolved via fallback",
        "i" = "Reference: {.val {schema_ref}}",
        "i" = "Primary location not found: {.path {primary_path}{schema_name}}",
        "i" = "Resolved from: {.path {secondary_path}{schema_name}}"
      ))
      schema_def <- fallback_def
    }
  }

  # Both failed - fatal error
  if (is.null(schema_def) || !is.list(schema_def)) {
    cli::cli_abort(c(
      "x" = "Cannot resolve schema reference: {.val {schema_ref}}",
      "i" = "Tried: {.path {primary_path}{schema_name}}, {.path {secondary_path}{schema_name}}",
      "i" = "Available in primary: {.val {names(primary_container)}}",
      "i" = if (!is.null(endpoint_context)) {
        paste0(
          "Endpoint: ",
          endpoint_context$method,
          " ",
          endpoint_context$route
        )
      } else {
        NULL
      }
    ))
  }

  # Warn if resolved schema is empty
  if (
    length(schema_def) == 0 ||
      (is.null(schema_def$type) &&
        is.null(schema_def$properties) &&
        is.null(schema_def[["$ref"]]))
  ) {
    cli::cli_warn(c(
      "!" = "Resolved schema is empty: {.val {schema_ref}}",
      "i" = "Schema exists but has no type, properties, or nested $ref",
      "i" = "Treating as valid but may indicate schema authoring issue"
    ))
  }

  # Handle schema composition (allOf, oneOf, anyOf) - recurse with depth tracking
  if (!is.null(schema_def[["allOf"]])) {
    return(resolve_schema_ref(
      schema_def[["allOf"]][[1]],
      components,
      schema_version,
      max_depth,
      depth + 1,
      endpoint_context
    ))
  }

  # Handle nested $ref in resolved schema
  if (!is.null(schema_def[["$ref"]])) {
    return(resolve_schema_ref(
      schema_def[["$ref"]],
      components,
      schema_version,
      max_depth,
      depth + 1,
      endpoint_context
    ))
  }

  # Return resolved schema
  schema_def
}

# Detect OpenAPI/Swagger version from schema root
# Returns list with: version (string), type ("swagger"|"openapi"|"unknown")
detect_schema_version <- function(schema) {
  # Check swagger field first (Swagger 2.0)
  if (
    !is.null(schema$swagger) && grepl("^2\\.", as.character(schema$swagger))
  ) {
    return(list(version = as.character(schema$swagger), type = "swagger"))
  }
  # Check openapi field (OpenAPI 3.x)
  if (
    !is.null(schema$openapi) && grepl("^3\\.", as.character(schema$openapi))
  ) {
    return(list(version = as.character(schema$openapi), type = "openapi"))
  }
  # Unknown version
  return(list(version = "unknown", type = "unknown"))
}

# Extract body schema from Swagger 2.0 parameters array
# Swagger 2.0 uses parameters[].in="body" with schema property
# Returns: list with type, properties (matching extract_body_properties output format)
extract_swagger2_body_schema <- function(parameters, definitions) {
  if (is.null(parameters) || !is.list(parameters) || length(parameters) == 0) {
    return(list(type = "unknown", properties = list()))
  }

  # Find body parameters (in="body")
  body_params <- purrr::keep(parameters, ~ identical(.x[["in"]], "body"))

  # Find formData parameters for mutual exclusivity check
  formData_params <- purrr::keep(
    parameters,
    ~ identical(.x[["in"]], "formData")
  )

  # BODY-06: Validate body/formData mutual exclusivity
  if (length(body_params) > 0 && length(formData_params) > 0) {
    cli::cli_alert_warning(
      "Swagger 2.0 spec violation: both body and formData parameters present. Using body parameter."
    )
  }

  # BODY-05: Validate single body parameter constraint
  if (length(body_params) > 1) {
    cli::cli_alert_warning(
      "Swagger 2.0 spec violation: multiple body parameters found ({length(body_params)}). Using first body parameter."
    )
  }

  if (length(body_params) == 0) {
    return(list(type = "unknown", properties = list()))
  }

  # Use first body parameter
  body_param <- body_params[[1]]
  body_schema <- body_param[["schema"]] %||% list()

  if (length(body_schema) == 0) {
    return(list(type = "unknown", properties = list()))
  }

  # Check for $ref to #/definitions/
  if (!is.null(body_schema[["$ref"]])) {
    ref <- body_schema[["$ref"]]
    # BODY-03: Resolve $ref to #/definitions/{SchemaName}
    resolved <- resolve_swagger2_definition_ref(ref, definitions)
    if (!is.null(resolved)) {
      body_schema <- resolved
    }
  }

  # Now extract properties from resolved schema (same logic as OpenAPI 3.0)
  schema_type <- body_schema[["type"]] %||% NA

  # BODY-04: Handle object schemas with properties
  # In Swagger 2.0, schemas with properties often omit the explicit type="object"
  has_properties <- !is.null(body_schema[["properties"]]) &&
    length(body_schema[["properties"]]) > 0
  is_object <- (!is.na(schema_type) && schema_type == "object") ||
    (is.na(schema_type) && has_properties)

  if (is_object && has_properties) {
    required_fields <- body_schema[["required"]] %||% character(0)
    metadata <- purrr::imap(
      body_schema[["properties"]],
      function(prop, prop_name) {
        list(
          name = prop_name,
          type = prop[["type"]] %||% NA,
          format = prop[["format"]] %||% NA,
          description = prop[["description"]] %||% "",
          enum = prop[["enum"]] %||% NULL,
          default = prop[["default"]] %||% NA,
          required = prop_name %in% required_fields,
          example = prop[["example"]] %||% prop[["default"]] %||% NA
        )
      }
    )
    names(metadata) <- purrr::map_chr(metadata, ~ .x$name)
    return(list(type = "object", properties = metadata))
  }

  # Handle array type
  if (
    !is.na(schema_type) &&
      schema_type == "array" &&
      !is.null(body_schema[["items"]])
  ) {
    items <- body_schema[["items"]]

    # Resolve items $ref if present
    if (!is.null(items[["$ref"]])) {
      resolved_items <- resolve_swagger2_definition_ref(
        items[["$ref"]],
        definitions
      )
      if (
        !is.null(resolved_items) && !is.null(resolved_items[["properties"]])
      ) {
        required_fields <- resolved_items[["required"]] %||% character(0)
        metadata <- purrr::imap(
          resolved_items[["properties"]],
          function(prop, prop_name) {
            list(
              name = prop_name,
              type = prop[["type"]] %||% NA,
              format = prop[["format"]] %||% NA,
              description = prop[["description"]] %||% "",
              enum = prop[["enum"]] %||% NULL,
              default = prop[["default"]] %||% NA,
              required = prop_name %in% required_fields,
              example = prop[["example"]] %||% prop[["default"]] %||% NA
            )
          }
        )
        names(metadata) <- purrr::map_chr(metadata, ~ .x$name)
        ref_type <- stringr::str_replace(items[["$ref"]], "#/definitions/", "")
        return(list(
          type = "array",
          item_schema = list(ref_type = ref_type, properties = metadata)
        ))
      }
    }

    # Inline array items
    item_type <- items[["type"]] %||% NA
    if (!is.na(item_type) && item_type == "string") {
      metadata <- list(
        query = list(
          name = "query",
          type = "array",
          item_type = "string",
          format = NA,
          description = body_schema[["description"]] %||% "Array of strings",
          enum = NULL,
          default = NA,
          required = TRUE,
          example = items[["example"]] %||% NA
        )
      )
      return(list(
        type = "string_array",
        item_type = "string",
        properties = metadata
      ))
    }
  }

  # Handle simple string type
  if (!is.na(schema_type) && schema_type == "string") {
    metadata <- list(
      query = list(
        name = "query",
        type = "string",
        format = body_schema[["format"]] %||% NA,
        description = body_schema[["description"]] %||% "Query string",
        enum = body_schema[["enum"]] %||% NULL,
        default = body_schema[["default"]] %||% NA,
        required = TRUE,
        example = body_schema[["example"]] %||% NA
      )
    )
    return(list(type = "string", properties = metadata))
  }

  list(type = "unknown", properties = list())
}

# Resolve Swagger 2.0 definition reference
# Swagger 2.0 uses #/definitions/{SchemaName} (not #/components/schemas/)
resolve_swagger2_definition_ref <- function(ref, definitions) {
  if (is.null(ref) || !nzchar(ref)) {
    return(NULL)
  }

  # Parse #/definitions/{SchemaName}
  if (!grepl("^#/definitions/", ref)) {
    return(NULL)
  }

  schema_name <- stringr::str_replace(ref, "#/definitions/", "")

  if (is.null(definitions) || !is.list(definitions)) {
    return(NULL)
  }

  schema_def <- definitions[[schema_name]]
  if (is.null(schema_def) || !is.list(schema_def)) {
    return(NULL)
  }

  schema_def
}

# Extract body properties from request body
extract_body_properties <- function(
  request_body,
  components,
  schema_version = NULL
) {
  if (is.null(request_body) || !is.list(request_body)) {
    return(list())
  }

  # If schema_version indicates Swagger 2.0 and request_body is parameters array,
  # delegate to Swagger 2.0 extraction and return early
  if (!is.null(schema_version) && identical(schema_version$type, "swagger")) {
    # For Swagger 2.0: request_body is actually parameters, components is definitions
    return(extract_swagger2_body_schema(request_body, components))
  }

  # Navigate: requestBody -> content -> application/json -> schema
  content <- request_body[["content"]] %||% list()
  json_schema <- content[["application/json"]][["schema"]] %||% list()

  if (length(json_schema) == 0) {
    return(list())
  }

  # Resolve reference if present
  if (!is.null(json_schema[["$ref"]])) {
    json_schema <- resolve_schema_ref(
      json_schema[["$ref"]],
      components,
      schema_version,
      max_depth = 3
    )
  }

  if (!is.null(json_schema[["oneOf"]])) {
    variants <- lapply(json_schema[["oneOf"]], function(variant) {
      if (!is.null(variant[["$ref"]])) {
        variant <- tryCatch(
          resolve_schema_ref(
            variant[["$ref"]],
            components,
            schema_version,
            max_depth = 3
          ),
          error = function(...) NULL
        )
      }
      if (
        is.null(variant) ||
          !identical(variant[["type"]], "object") ||
          is.null(variant[["properties"]]) ||
          length(variant[["properties"]]) == 0
      ) {
        return(NULL)
      }
      variant
    })
    if (length(variants) == 0 || any(vapply(variants, is.null, logical(1)))) {
      return(list(type = "unknown", properties = list()))
    }

    required_by_variant <- lapply(variants, function(variant) {
      unlist(variant[["required"]] %||% character(0), use.names = FALSE)
    })
    required_fields <- Reduce(intersect, required_by_variant)
    properties <- list()
    for (variant in variants) {
      for (prop_name in names(variant[["properties"]])) {
        if (is.null(properties[[prop_name]])) {
          prop <- variant[["properties"]][[prop_name]]
          properties[[prop_name]] <- list(
            name = prop_name,
            type = prop[["type"]] %||% NA,
            format = prop[["format"]] %||% NA,
            description = prop[["description"]] %||% "",
            enum = prop[["enum"]] %||% NULL,
            default = prop[["default"]] %||% NA,
            required = prop_name %in% required_fields,
            example = prop[["example"]] %||% prop[["default"]] %||% NA
          )
        }
      }
    }
    return(list(
      type = "one_of",
      properties = properties,
      required_by_variant = required_by_variant
    ))
  }

  # Check schema type
  type <- json_schema[["type"]] %||% NA

  has_named_properties <- !is.null(json_schema[["properties"]]) &&
    length(json_schema[["properties"]]) > 0
  additional_properties <- json_schema[["additionalProperties"]]
  if (
    identical(type, "object") &&
      !has_named_properties &&
      !is.null(additional_properties) &&
      !identical(additional_properties, FALSE)
  ) {
    return(list(
      type = "unsupported_map",
      properties = list(),
      additional_properties = additional_properties
    ))
  }

  # Handle simple string type
  if (!is.na(type) && type == "string") {
    # Create synthetic parameter metadata for the string body
    metadata <- list(
      query = list(
        name = "query",
        type = "string",
        format = json_schema[["format"]] %||% NA,
        description = json_schema[["description"]] %||%
          "Query string to search for",
        enum = json_schema[["enum"]] %||% NULL,
        default = json_schema[["default"]] %||% NA,
        required = TRUE,
        example = json_schema[["example"]] %||% NA
      )
    )

    return(list(
      type = "string",
      properties = metadata
    ))
  }

  # If array, extract item type
  if (type == "array" && !is.null(json_schema[["items"]])) {
    items <- json_schema[["items"]]

    # If items is a reference, resolve it
    if (!is.null(items[["$ref"]])) {
      resolved <- resolve_schema_ref(
        items[["$ref"]],
        components,
        schema_version,
        max_depth = 3
      )

      # If resolved is object with properties, extract them
      if (!is.null(resolved[["properties"]])) {
        required_fields <- resolved[["required"]] %||% character(0)
        metadata <- purrr::imap(
          resolved[["properties"]],
          function(prop, prop_name) {
            list(
              name = prop_name,
              type = prop[["type"]] %||% NA,
              format = prop[["format"]] %||% NA,
              description = prop[["description"]] %||% "",
              enum = prop[["enum"]] %||% NULL,
              default = prop[["default"]] %||% NA,
              required = prop_name %in% required_fields,
              example = prop[["example"]] %||% prop[["default"]] %||% NA
            )
          }
        )
        names(metadata) <- purrr::map_chr(metadata, ~ .x$name)
        return(list(
          type = "array",
          item_schema = list(
            ref_type = stringr::str_replace(
              items[["$ref"]],
              "#/components/schemas/",
              ""
            ),
            properties = metadata
          )
        ))
      }
    }

    # Array with inline object items (no $ref, but has type: object with properties)
    item_type <- items[["type"]] %||% NA
    if (
      !is.na(item_type) &&
        item_type == "object" &&
        !is.null(items[["properties"]])
    ) {
      required_fields <- items[["required"]] %||% character(0)
      metadata <- purrr::imap(items[["properties"]], function(prop, prop_name) {
        list(
          name = prop_name,
          type = prop[["type"]] %||% NA,
          format = prop[["format"]] %||% NA,
          description = prop[["description"]] %||% "",
          enum = prop[["enum"]] %||% NULL,
          default = prop[["default"]] %||% NA,
          required = prop_name %in% required_fields,
          example = prop[["example"]] %||% prop[["default"]] %||% NA
        )
      })
      names(metadata) <- purrr::map_chr(metadata, ~ .x$name)
      return(list(
        type = "object_array",
        item_schema = list(
          inline = TRUE,
          properties = metadata
        )
      ))
    }

    # Simple array (e.g., string array)
    if (!is.na(item_type) && item_type == "string") {
      # String array - create query parameter metadata
      metadata <- list(
        query = list(
          name = "query",
          type = "array",
          item_type = "string",
          format = json_schema[["format"]] %||% NA,
          description = json_schema[["description"]] %||%
            "Array of strings to search for",
          enum = json_schema[["enum"]] %||% NULL,
          default = json_schema[["default"]] %||% NA,
          required = TRUE,
          example = json_schema[["example"]] %||% items[["example"]] %||% NA
        )
      )

      return(list(
        type = "string_array",
        item_type = "string",
        properties = metadata
      ))
    }

    # Non-string arrays without object items
    return(list(
      type = "array",
      item_type = item_type,
      properties = list()
    ))
  }

  # If object, extract properties
  if (type == "object" && !is.null(json_schema[["properties"]])) {
    required_fields <- json_schema[["required"]] %||% character(0)

    metadata <- purrr::imap(
      json_schema[["properties"]],
      function(prop, prop_name) {
        list(
          name = prop_name,
          type = prop[["type"]] %||% NA,
          format = prop[["format"]] %||% NA,
          description = prop[["description"]] %||% "",
          enum = prop[["enum"]] %||% NULL,
          default = prop[["default"]] %||% NA,
          required = prop_name %in% required_fields,
          example = prop[["example"]] %||% prop[["default"]] %||% NA
        )
      }
    )

    names(metadata) <- purrr::map_chr(metadata, ~ .x$name)
    return(list(
      type = "object",
      properties = metadata
    ))
  }

  # Unknown schema type
  list(type = "unknown", properties = list())
}

#' Select schema files with optional stage-based prioritization
#'
# Extract query parameters with schema reference resolution
# Flattens referenced schemas into individual query parameters
extract_query_params_with_refs <- function(
  parameters,
  components,
  schema_version = NULL,
  max_depth = 3
) {
  result_names <- character(0)
  result_metadata <- list()

  for (param in parameters) {
    if (is.null(param) || !is.list(param)) {
      next
    }

    param_name <- param[["name"]] %||% ""
    param_in <- param[["in"]] %||% ""

    # Only process query parameters
    if (param_in != "query") {
      next
    }

    schema <- param[["schema"]] %||% list()

    # Check if parameter has $ref
    schema_ref <- schema[["$ref"]]

    if (!is.null(schema_ref) && nzchar(schema_ref)) {
      # Resolve the schema reference
      resolved <- resolve_schema_ref(
        schema_ref,
        components,
        schema_version,
        max_depth,
        depth = 0
      )

      # Check if resolved schema has properties (object)
      properties <- resolved[["properties"]] %||% list()
      required_fields <- resolved[["required"]] %||% character(0)

      if (length(properties) == 0) {
        # Simple type (string, integer, boolean, etc.)
        result_names <- c(result_names, param_name)
        result_metadata[[param_name]] <- list(
          name = param_name,
          type = schema[["type"]] %||% resolved[["type"]] %||% NA,
          format = schema[["format"]] %||% resolved[["format"]] %||% NA,
          description = param[["description"]] %||%
            resolved[["description"]] %||%
            "",
          enum = schema[["enum"]] %||% resolved[["enum"]] %||% NULL,
          default = schema[["default"]] %||% resolved[["default"]] %||% NA,
          required = param[["required"]] %||% FALSE,
          example = param[["example"]] %||% schema[["default"]] %||% NA
        )
      } else {
        # Object with properties - flatten into individual params
        # Use dot notation for nested properties
        for (prop_name in names(properties)) {
          prop <- properties[[prop_name]]

          # Check if property has $ref and resolve it
          prop_ref <- prop[["$ref"]]
          if (!is.null(prop_ref) && nzchar(prop_ref)) {
            # Resolve the nested $ref
            prop <- resolve_schema_ref(
              prop_ref,
              components,
              schema_version,
              max_depth,
              1
            )
          }

          # Extract property metadata first
          prop_type <- prop[["type"]] %||% NA
          prop_format <- prop[["format"]] %||% NA
          prop_desc <- prop[["description"]] %||% ""
          prop_enum <- prop[["enum"]] %||% NULL
          prop_default <- prop[["default"]] %||% NA
          prop_required <- prop_name %in% required_fields
          prop_example <- prop[["example"]] %||% prop_default %||% NA

          # Handle nested objects with dot notation
          if (
            !is.na(prop_type) &&
              prop_type == "object" &&
              !is.null(prop[["properties"]])
          ) {
            # This is a nested object - recurse with dot notation
            # DON'T add the parent object to result_names, only the nested properties
            nested_props <- prop[["properties"]]
            nested_required <- prop[["required"]] %||% character(0)

            for (nested_name in names(nested_props)) {
              nested_prop <- nested_props[[nested_name]]
              nested_flat_name <- paste0(
                param_name,
                ".",
                prop_name,
                ".",
                nested_name
              )
              result_names <- c(result_names, nested_flat_name)

              result_metadata[[nested_flat_name]] <- list(
                name = nested_flat_name,
                type = nested_prop[["type"]] %||% NA,
                format = nested_prop[["format"]] %||% NA,
                description = nested_prop[["description"]] %||% "",
                enum = nested_prop[["enum"]] %||% NULL,
                default = nested_prop[["default"]] %||% NA,
                required = nested_name %in% nested_required,
                example = nested_prop[["example"]] %||%
                  nested_prop[["default"]] %||%
                  NA
              )
            }
          } else {
            # Simple property or array (not an object with nested properties)
            flat_name <- paste0(param_name, ".", prop_name)

            # Check if array type and reject binary arrays
            if (!is.na(prop_type) && prop_type == "array") {
              items <- prop[["items"]] %||% list()
              items_type <- items[["type"]] %||% NA
              items_format <- items[["format"]] %||% NA

              # REJECT binary arrays (e.g., files[])
              if (!is.na(items_format) && items_format == "binary") {
                # Skip binary arrays - don't include in query params
                next
              }

              # Support non-binary arrays
              result_names <- c(result_names, flat_name)
              result_metadata[[flat_name]] <- list(
                name = flat_name,
                type = "array",
                item_type = items_type,
                format = prop_format,
                description = prop_desc,
                enum = prop_enum,
                default = prop_default,
                required = prop_required,
                example = prop_example
              )
            } else {
              # Simple property
              result_names <- c(result_names, flat_name)
              result_metadata[[flat_name]] <- list(
                name = flat_name,
                type = prop_type,
                format = prop_format,
                description = prop_desc,
                enum = prop_enum,
                default = prop_default,
                required = prop_required,
                example = prop_example
              )
            }
          }
        }
      }
    } else {
      # No $ref - simple parameter with inline schema
      # REJECT binary arrays (e.g., files[])
      schema_type <- schema[["type"]] %||% NA
      schema_format <- schema[["format"]] %||% NA
      if (!is.na(schema_type) && schema_type == "array") {
        items <- schema[["items"]] %||% list()
        items_format <- items[["format"]] %||% NA
        if (!is.na(items_format) && items_format == "binary") {
          # Skip binary arrays - don't include in query params
          next
        }
      }

      result_names <- c(result_names, param_name)
      result_metadata[[param_name]] <- list(
        name = param_name,
        type = schema_type,
        format = schema_format,
        description = param[["description"]] %||% "",
        enum = schema[["enum"]] %||% NULL,
        default = schema[["default"]] %||% NA,
        required = param[["required"]] %||% FALSE,
        example = param[["example"]] %||% schema[["default"]] %||% NA
      )
    }
  }

  list(names = result_names, metadata = result_metadata)
}
