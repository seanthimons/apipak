form_media <- function(media) {
  isTRUE(
    media %in% c('application/x-www-form-urlencoded', 'multipart/form-data')
  )
}

request_body_media <- function(available, preferred = NULL, at = '#') {
  supported <- c(
    'application/json',
    'application/octet-stream',
    'application/x-www-form-urlencoded',
    'multipart/form-data'
  )
  available <- unlist(available, use.names = FALSE)
  selected <- if (is.null(preferred)) {
    intersect(supported, available)[1L]
  } else {
    preferred
  }
  if (
    length(selected) != 1L ||
      is.na(selected) ||
      !selected %in% intersect(supported, available)
  ) {
    schema_problem(
      'body_media_type',
      'capability_gap',
      if (is.null(preferred)) {
        'Unsupported body media type'
      } else {
        'Requested body media type is unavailable'
      },
      at
    )
  }
  selected
}

form_encoding <- function(schema, encoding, media, at) {
  fail <- function(message) {
    schema_problem('form_encoding', 'capability_gap', message, at)
  }
  if (!identical(schema$type, 'object')) {
    fail('Form body must be an object')
  }
  if (is.list(schema$additionalProperties)) {
    fail('Dynamic form fields are unsupported')
  }
  if (length(setdiff(names(encoding), names(schema$properties)))) {
    fail('Encoding names an undeclared form property')
  }
  for (name in names(schema$properties)) {
    field <- schema$properties[[name]]
    enc <- encoding[[name]] %or% list()
    if (length(enc$headers)) {
      fail('Multipart part headers require an explicit request mapping')
    }
    if (media == 'application/x-www-form-urlencoded') {
      if (
        identical(field$format, 'binary') ||
          identical(field$items$format, 'binary')
      ) {
        fail('Binary form fields require multipart/form-data')
      }
      if (
        identical(field$type, 'object') || identical(field$items$type, 'object')
      ) {
        fail('Nested URL-encoded form fields are unsupported')
      }
      if (!is.null(enc$contentType)) {
        fail('Content-Type encoding for URL-encoded fields is unsupported')
      }
      p <- c(
        list(name = name, 'in' = 'query'),
        enc[c('style', 'explode', 'allowReserved')]
      )
      # NULL entries do not override the parameter defaults.
      if (!is.null(enc$collection_format)) {
        p$collectionFormat <- enc$collection_format
        parameter_shape(p, field, '2.0', at)
      } else {
        parameter_shape(p, field, '3.0.3', at)
      }
    } else {
      type <- if (identical(field$type, 'array')) field$items else field
      content <- enc$contentType
      if (
        !is.null(enc$collection_format) &&
          !enc$collection_format %in% c('csv', 'ssv', 'tsv', 'pipes', 'multi')
      ) {
        fail('Unsupported form collectionFormat')
      }
      if (
        identical(field$type, 'array') &&
          identical(field$items$format, 'binary') &&
          !is.null(enc$collection_format) &&
          enc$collection_format != 'multi'
      ) {
        fail('Binary multipart arrays require collectionFormat multi')
      }
      if (
        !is.null(content) &&
          (!is.character(content) ||
            length(content) != 1L ||
            !grepl('^[A-Za-z0-9!#$&^_.+-]+/[A-Za-z0-9!#$&^_.+-]+$', content))
      ) {
        fail('Multipart encoding requires one concrete Content-Type')
      }
      if (
        identical(type$type, 'object') &&
          !is.null(content) &&
          content != 'application/json'
      ) {
        fail('Multipart object parts require application/json')
      }
      if (identical(type$type, 'array') || is.null(type$type)) {
        fail('Unsupported multipart part shape')
      }
    }
  }
  encoding %or% list()
}

# Self-contained except for the supplied JSON validator, which is embedded too.
form_value <- function(value, schema, validate, allow_empty = TRUE) {
  if (
    is.null(value) ||
      !is.list(value) ||
      (length(value) && is.null(names(value)))
  ) {
    stop('Form body must be a named list; omit the body argument to omit it')
  }
  if (!length(value) && !allow_empty) {
    stop('Empty multipart forms cannot be encoded')
  }
  original <- list()
  for (name in names(value)) {
    field <- schema$properties[[name]]
    if (is.null(field) && is.list(schema$additionalProperties)) {
      field <- schema$additionalProperties
    }
    if (is.null(field$type)) {
      stop('Form field needs a declared schema: ', name)
    }
    if (is.null(value[[name]])) {
      stop('Null form fields have no unambiguous encoding: ', name)
    }
    if (identical(field$type, 'array') && !length(value[[name]])) {
      stop('Empty form arrays have no unambiguous encoding: ', name)
    }
    type <- if (identical(field$type, 'array')) field$items else field
    if (identical(type$format, 'binary')) {
      parts <- if (identical(field$type, 'array')) {
        value[[name]]
      } else {
        list(value[[name]])
      }
      if (
        !is.list(parts) ||
          !is.null(names(parts)) ||
          !length(parts) ||
          !all(vapply(
            parts,
            function(x) is.raw(x) || inherits(x, 'form_file'),
            logical(1)
          ))
      ) {
        stop(
          'Binary form fields must be raw vectors or curl::form_file() values'
        )
      }
      original[name] <- value[name]
      value[name] <- list(
        if (identical(field$type, 'array')) rep(list(''), length(parts)) else ''
      )
    }
  }
  value <- validate(value, schema)
  for (name in names(original)) {
    value[name] <- original[name]
  }
  value
}

form_checks <- function(schema, value, media) {
  paste0(
    value,
    ' <- base::evalq(',
    r_literal(form_value),
    ', envir = base::baseenv())(',
    value,
    ', base::evalq(',
    r_literal(schema),
    ', envir = base::baseenv())',
    ', base::evalq(',
    r_literal(body_value),
    ', envir = base::baseenv())',
    ', ',
    r_literal(identical(media, 'application/x-www-form-urlencoded')),
    ')'
  )
}

form_fixture <- function(schema, allow_empty = TRUE) {
  value <- body_fixture_value(schema)
  for (name in names(value)) {
    field <- schema$properties[[name]] %or% schema$additionalProperties
    if (identical(field$format, 'binary')) {
      value[name] <- list(as.raw(c(0, 255)))
    }
    if (
      identical(field$type, 'array') && identical(field$items$format, 'binary')
    ) {
      value[name] <- list(rep(
        list(as.raw(c(0, 255))),
        max(1L, length(value[[name]]))
      ))
    }
    if (identical(field$type, 'array') && !length(value[[name]])) {
      value[name] <- list(list(body_fixture_value(field$items)))
    }
  }
  form_value(value, schema, body_value, allow_empty)
}
