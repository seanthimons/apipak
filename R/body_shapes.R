supported_body <- function(body, document, array = TRUE) {
  body <- local_ref(body, document)
  if (any(c('oneOf', 'anyOf', 'allOf') %in% names(body))) {
    stop('Unsupported body composition')
  }
  if (identical(body$type, 'array') && array) {
    body$items <- supported_body(body$items, document, array = FALSE)
  } else if (identical(body$type, 'object')) {
    if (
      !length(body$properties) ||
        !is.null(body$additionalProperties) &&
          !isFALSE(body$additionalProperties)
    ) {
      stop('Unsupported free-form body object')
    }
    body$properties <- lapply(body$properties, function(p) {
      p <- local_ref(p, document)
      if (
        !p$type %in% c('string', 'integer', 'number', 'boolean') ||
          any(c('oneOf', 'anyOf', 'allOf') %in% names(p))
      ) {
        stop('Unsupported body property')
      }
      p
    })
  } else if (
    array || !body$type %in% c('string', 'integer', 'number', 'boolean')
  ) {
    stop('Unsupported body shape')
  }
  body
}

body_fixture <- function(schema, override = NULL) {
  if (identical(schema$type, 'array')) {
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
      body_fixture(schema$items, override[[i]])
    }))
  }
  if (identical(schema$type, 'object')) {
    return(setNames(
      lapply(names(schema$properties), function(name) {
        fixture_value(schema$properties[[name]], override[[name]])
      }),
      names(schema$properties)
    ))
  }
  fixture_value(schema, override)
}
