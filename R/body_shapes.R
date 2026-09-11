supported_body <- function(
  body,
  document,
  seen = character(),
  source_location = '#'
) {
  fail <- function(
    code,
    message,
    classification = 'capability_gap',
    at = source_location
  ) {
    schema_problem(code, classification, message, at)
  }
  if (!is.list(body)) {
    fail('body_shape', 'Unsupported body shape')
  }
  ref <- body[['$ref']]
  body <- local_ref(body, document, seen, source_location)
  if (!is.null(ref)) {
    source_location <- ref
  }
  seen <- c(seen, ref)
  if (any(c('oneOf', 'anyOf', 'allOf') %in% names(body))) {
    fail('body_composition', 'Unsupported body composition')
  }
  if (is.null(body$type) && length(body$properties)) {
    body$type <- 'object'
  }
  if (identical(body$type, 'array')) {
    if (is.null(body$items)) {
      body$items <- list()
    }
    body$items <- supported_body(
      body$items,
      document,
      seen,
      schema_location(source_location, 'items')
    )
  } else if (identical(body$type, 'object')) {
    if (
      length(body$properties) &&
        (is.null(names(body$properties)) ||
          any(!nzchar(names(body$properties))))
    ) {
      fail('invalid_properties', 'Invalid body properties', 'schema_defect')
    }
    required <- unlist(body$required, use.names = FALSE)
    if (
      length(required) &&
        (!is.character(required) ||
          (isFALSE(body$additionalProperties) &&
            any(!required %in% names(body$properties))))
    ) {
      fail('invalid_required', 'Invalid required body fields', 'schema_defect')
    }
    if (is.list(body$additionalProperties)) {
      body$additionalProperties <- supported_body(
        body$additionalProperties,
        document,
        seen,
        schema_location(source_location, 'additionalProperties')
      )
    }
    body$properties <- stats::setNames(
      lapply(
        names(body$properties),
        function(name) {
          supported_body(
            body$properties[[name]],
            document,
            seen,
            schema_location(
              schema_location(source_location, 'properties'),
              name
            )
          )
        }
      ),
      names(body$properties)
    )
  } else if (
    is.null(body$type) &&
      !length(setdiff(
        names(body),
        c(
          'title',
          'description',
          'example',
          'default',
          'nullable',
          'readOnly',
          'writeOnly',
          'deprecated'
        )
      ))
  ) {
    return(body)
  } else if (
    length(body$type) != 1L ||
      !body$type %in% c('string', 'integer', 'number', 'boolean')
  ) {
    fail('body_shape', 'Unsupported body shape')
  }
  body
}

body_fixture <- function(schema, override = NULL) {
  value <- if (missing(override)) {
    body_fixture_value(schema)
  } else {
    body_fixture_value(schema, override)
  }
  body_value(value, schema)
}

body_fixture_value <- function(schema, override = NULL) {
  if (!missing(override)) {
    return(override)
  }
  for (field in c('example', 'default')) {
    if (field %in% names(schema)) return(schema[[field]])
  }
  if (length(schema$enum)) {
    return(schema$enum[[1L]])
  }
  if (is.null(schema$type)) {
    return(list())
  }
  if (identical(schema$type, 'array')) {
    return(lapply(seq_len(schema$minItems %or% 1L), function(i) {
      body_fixture_value(schema$items)
    }))
  }
  if (identical(schema$type, 'object')) {
    keys <- union(names(schema$properties), unlist(schema$required)) %or%
      character()
    return(setNames(
      lapply(keys, function(name) {
        child <- schema$properties[[name]] %or%
          if (is.list(schema$additionalProperties)) {
            schema$additionalProperties
          } else {
            list()
          }
        body_fixture_value(child)
      }),
      keys
    ))
  }
  fixture_value(schema)
}

# Self-contained: generated clients need no specmill runtime or new helper argument.
body_value <- function(value, schema) {
  validate <- function(value, schema) {
    type <- schema$type
    if (is.null(value)) {
      if (is.null(type) || isTRUE(schema$nullable)) {
        return(NULL)
      }
      stop('Explicit null body is not nullable')
    }
    if (is.object(value) || !is.null(dim(value))) {
      stop('Body must contain plain JSON values')
    }
    if (
      identical(type, 'object') ||
        (is.null(type) && is.list(value) && !is.null(names(value)))
    ) {
      if (!is.list(value) || (length(value) && is.null(names(value)))) {
        stop('Object body must be a named list')
      }
      keys <- names(value)
      if (anyNA(keys) || anyDuplicated(keys) || any(!nzchar(keys))) {
        stop('Invalid body object names')
      }
      if (!all(unlist(schema$required) %in% keys)) {
        stop('Missing required body fields')
      }
      unknown <- setdiff(keys, names(schema$properties))
      if (length(unknown) && isFALSE(schema$additionalProperties)) {
        stop('Unknown body fields')
      }
      value <- lapply(seq_along(value), function(i) {
        name <- keys[[i]]
        child <- schema$properties[[name]]
        if (is.null(child)) {
          child <- if (is.list(schema$additionalProperties)) {
            schema$additionalProperties
          } else {
            list()
          }
        }
        validate(value[[i]], child)
      })
      names(value) <- if (length(keys)) keys else character()
    } else if (identical(type, 'array') || (is.null(type) && is.list(value))) {
      if (!is.list(value) || !is.null(names(value))) {
        stop('Array body must be an unnamed list')
      }
      if (
        (!is.null(schema$minItems) && length(value) < schema$minItems) ||
          (!is.null(schema$maxItems) && length(value) > schema$maxItems)
      ) {
        stop('Invalid body array length')
      }
      value <- lapply(value, validate, schema = schema$items)
    } else {
      valid <- is.atomic(value) &&
        length(value) == 1L &&
        !anyNA(value) &&
        is.null(names(value))
      if (valid) {
        valid <- switch(
          if (is.null(type)) 'any' else type,
          string = is.character(value),
          integer = is.numeric(value) &&
            is.finite(value) &&
            value == trunc(value),
          number = is.numeric(value) && is.finite(value),
          boolean = is.logical(value),
          any = is.character(value) ||
            is.logical(value) ||
            (is.numeric(value) && is.finite(value)),
          FALSE
        )
      }
      if (!isTRUE(valid)) {
        stop('Invalid body scalar type')
      }
      if (!is.null(schema$enum) && !value %in% unlist(schema$enum)) {
        stop('Invalid body enum')
      }
      if (
        (!is.null(schema$minimum) && value < schema$minimum) ||
          (!is.null(schema$maximum) && value > schema$maximum)
      ) {
        stop('Invalid body numeric bounds')
      }
      if (
        (!is.null(schema$minLength) && nchar(value) < schema$minLength) ||
          (!is.null(schema$maxLength) && nchar(value) > schema$maxLength) ||
          (!is.null(schema$pattern) &&
            !grepl(schema$pattern, value, perl = TRUE))
      ) {
        stop('Invalid body string')
      }
    }
    value
  }
  validate(value, schema)
}

body_checks <- function(schema, value) {
  paste0(
    value,
    ' <- (',
    r_literal(body_value),
    ')(',
    value,
    ', ',
    r_literal(schema),
    ')'
  )
}
