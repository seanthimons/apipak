supported_body <- function(body, document, seen = character()) {
  if (!is.list(body) || !length(body)) {
    stop('Missing body schema')
  }
  ref <- body[['$ref']]
  body <- local_ref(body, document, seen)
  seen <- c(seen, ref)
  if (any(c('oneOf', 'anyOf', 'allOf') %in% names(body))) {
    stop('Unsupported body composition')
  }
  if (is.null(body$type) && length(body$properties)) {
    body$type <- 'object'
  }
  if (identical(body$type, 'array')) {
    body$items <- supported_body(body$items, document, seen)
  } else if (identical(body$type, 'object')) {
    if (
      !length(body$properties) ||
        !is.null(body$additionalProperties) &&
          !isFALSE(body$additionalProperties)
    ) {
      stop('Unsupported free-form body object')
    }
    if (
      is.null(names(body$properties)) || any(!nzchar(names(body$properties)))
    ) {
      stop('Invalid body properties')
    }
    required <- unlist(body$required, use.names = FALSE)
    if (
      length(required) &&
        (!is.character(required) || any(!required %in% names(body$properties)))
    ) {
      stop('Invalid required body fields')
    }
    body$properties <- lapply(
      body$properties,
      supported_body,
      document = document,
      seen = seen
    )
  } else if (
    length(body$type) != 1L ||
      !body$type %in% c('string', 'integer', 'number', 'boolean')
  ) {
    stop('Unsupported body shape')
  }
  body
}

body_fixture <- function(schema, override = NULL) {
  if (missing(override)) {
    for (field in c('example', 'default')) {
      if (field %in% names(schema)) {
        return(body_fixture(schema, schema[[field]]))
      }
    }
    if (length(schema$enum)) return(body_fixture(schema, schema$enum[[1L]]))
  }
  if (!missing(override) && is.null(override)) {
    if (isTRUE(schema$nullable) || 'null' %in% schema$type) {
      return(NULL)
    }
    stop('Explicit null body fixture is not nullable')
  }
  if (identical(schema$type, 'array')) {
    if (
      !missing(override) && (!is.list(override) || !is.null(names(override)))
    ) {
      stop('Array fixture must be an unnamed list')
    }
    count <- if (is.null(override)) {
      schema$minItems %or% 1L
    } else {
      length(override)
    }
    if (
      !is.null(schema$minItems) &&
        count < schema$minItems ||
        !is.null(schema$maxItems) && count > schema$maxItems
    ) {
      stop('Invalid array fixture length')
    }
    return(lapply(seq_len(count), function(i) {
      if (is.null(override)) {
        body_fixture(schema$items)
      } else {
        body_fixture(schema$items, override[[i]])
      }
    }))
  }
  if (identical(schema$type, 'object')) {
    if (!missing(override)) {
      if (
        !is.list(override) ||
          (length(override) && is.null(names(override))) ||
          !all(unlist(schema$required) %in% names(override))
      ) {
        stop('Missing required body fields in fixture')
      }
      unknown <- setdiff(names(override), names(schema$properties))
      if (length(unknown) && isFALSE(schema$additionalProperties)) {
        stop('Unknown body fixture fields')
      }
      for (name in intersect(names(override), names(schema$properties))) {
        override[name] <- list(body_fixture(
          schema$properties[[name]],
          override[[name]]
        ))
      }
      return(override)
    }
    return(setNames(
      lapply(names(schema$properties), function(name) {
        body_fixture(schema$properties[[name]])
      }),
      names(schema$properties)
    ))
  }
  if (missing(override)) {
    fixture_value(schema)
  } else {
    fixture_value(schema, override)
  }
}

# Emit presence checks for nested containers without adding a runtime dependency.
body_checks <- function(schema, value, depth = 0L) {
  if (schema$type == 'object') {
    lines <- paste0(
      'if (!is.list(',
      value,
      ') || !all(',
      r_literal(unlist(schema$required %or% character())),
      ' %in% names(',
      value,
      '))) stop("Missing required body fields")'
    )
    for (name in names(schema$properties)) {
      child <- schema$properties[[name]]
      expression <- paste0(value, '[[', r_literal(name), ']]')
      if (child$type %in% c('array', 'object')) {
        lines <- c(
          lines,
          paste0('if (!is.null(', expression, ')) {'),
          paste0('  ', body_checks(child, expression, depth + 1L)),
          '}'
        )
      }
    }
    lines
  } else if (schema$type == 'array') {
    item <- paste0('.item', depth)
    lines <- paste0(
      'if (!is.list(',
      value,
      ')) stop("Array body must be a list")'
    )
    if (schema$items$type %in% c('array', 'object')) {
      lines <- c(
        lines,
        paste0('invisible(lapply(', value, ', function(', item, ') {'),
        paste0('  ', body_checks(schema$items, item, depth + 1L)),
        '}))'
      )
    }
    lines
  } else {
    character()
  }
}
