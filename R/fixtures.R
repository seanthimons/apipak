fixture_value <- function(schema, override = NULL) {
  if (identical(schema$type, 'object')) {
    if (
      missing(override) &&
        !any(c('example', 'default', 'enum') %in% names(schema))
    ) {
      keys <- union(names(schema$properties), unlist(schema$required))
      if (!length(keys) && !isFALSE(schema$additionalProperties)) {
        keys <- 'example'
      }
      override <- setNames(
        lapply(keys, function(name) {
          child <- schema$properties[[name]] %or%
            if (is.list(schema$additionalProperties)) {
              schema$additionalProperties
            } else {
              list()
            }
          if (is.null(child$type)) {
            child$type <- 'string'
          }
          fixture_value(child)
        }),
        keys
      )
    }
    value <- if (missing(override)) {
      body_fixture(schema)
    } else {
      body_fixture(schema, override)
    }
    if (
      !length(value) ||
        any(vapply(
          value,
          function(x) is.list(x) || length(x) != 1L,
          logical(1)
        ))
    ) {
      stop('Parameter fixture must be a nonempty flat object')
    }
    return(value)
  }
  if (identical(schema$type, 'array')) {
    value <- if (missing(override)) {
      body_fixture(schema)
    } else {
      body_fixture(schema, as.list(override))
    }
    value <- unlist(value, use.names = FALSE)
    if (!length(value)) {
      stop('Parameter fixture must be a nonempty array')
    }
    return(switch(
      schema$items$type,
      string = as.character(value),
      integer = as.integer(value),
      number = as.numeric(value),
      boolean = as.logical(value)
    ))
  }
  if (!missing(override) && is.null(override)) {
    if (isTRUE(schema$nullable) || 'null' %in% schema$type) {
      return(NULL)
    }
    stop('Explicit null fixture is not nullable')
  }
  value <- if (!missing(override)) {
    override
  } else {
    schema$example %or%
      schema$default %or%
      schema$enum[[1L]]
  }
  if (is.null(value)) {
    value <- switch(
      schema$type,
      string = 'example',
      integer = 1L,
      number = 1,
      boolean = TRUE
    )
  }
  valid <- length(value) == 1L &&
    !is.na(value) &&
    switch(
      schema$type,
      string = is.character(value),
      integer = is.numeric(value) && value == trunc(value),
      number = is.numeric(value) && is.finite(value),
      boolean = is.logical(value),
      FALSE
    )
  if (valid && !is.null(schema$enum)) {
    valid <- value %in% unlist(schema$enum)
  }
  if (valid && !is.null(schema$minimum)) {
    valid <- value >= schema$minimum
  }
  if (valid && !is.null(schema$maximum)) {
    valid <- value <= schema$maximum
  }
  if (valid && !is.null(schema$minLength)) {
    valid <- nchar(value) >= schema$minLength
  }
  if (valid && !is.null(schema$maxLength)) {
    valid <- nchar(value) <= schema$maxLength
  }
  if (valid && !is.null(schema$pattern)) {
    valid <- grepl(schema$pattern, value, perl = TRUE)
  }
  if (!isTRUE(valid)) {
    stop('No valid fixture: supply a reviewed override', call. = FALSE)
  }
  value
}

operation_fixtures <- function(operations, overrides = list()) {
  lapply(operations, function(op) {
    inputs <- setNames(
      lapply(op$parameters, function(p) {
        if (p$name %in% names(overrides[[op$name]])) {
          fixture_value(p$schema, overrides[[op$name]][[p$name]])
        } else {
          fixture_value(p$schema)
        }
      }),
      parameter_names(op$parameters)
    )
    if (!is.null(op$body)) {
      if (identical(op$body_media, 'application/octet-stream')) {
        value <- if ('body' %in% names(overrides[[op$name]])) {
          overrides[[op$name]]$body
        } else {
          as.raw(0L)
        }
        if (!is.raw(value)) {
          stop('Binary fixture must be a raw vector')
        }
        inputs['body'] <- list(value)
      } else {
        inputs['body'] <- list(
          if ('body' %in% names(overrides[[op$name]])) {
            body_fixture(op$body, overrides[[op$name]]$body)
          } else {
            body_fixture(op$body)
          }
        )
      }
    }
    inputs
  })
}
