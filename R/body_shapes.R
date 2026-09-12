supported_body <- function(
  body,
  document,
  seen = character(),
  source_location = '#',
  allow_composition = TRUE,
  in_composition = FALSE
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
  composition <- intersect(names(body), c('oneOf', 'anyOf', 'allOf'))
  composed <- in_composition || length(composition) || length(body$type) > 1L
  if (length(composition) && !allow_composition) {
    fail('body_composition', 'Unsupported body composition')
  }
  if (allow_composition) {
    known <- c(
      '$ref',
      'type',
      'properties',
      'required',
      'additionalProperties',
      'items',
      'oneOf',
      'anyOf',
      'allOf',
      'enum',
      'const',
      'minimum',
      'maximum',
      'exclusiveMinimum',
      'exclusiveMaximum',
      'multipleOf',
      'minLength',
      'maxLength',
      'pattern',
      'minItems',
      'maxItems',
      'uniqueItems',
      'minProperties',
      'maxProperties',
      'title',
      'description',
      'default',
      'example',
      'examples',
      'nullable',
      'readOnly',
      'writeOnly',
      'deprecated',
      'format',
      'discriminator',
      'xml',
      '$id',
      '$schema',
      '$comment',
      'externalDocs',
      'contentEncoding',
      'contentMediaType'
    )
    unknown <- setdiff(names(body), known)
    unknown <- unknown[!startsWith(unknown, 'x-')]
    if (length(unknown)) {
      fail(
        'body_keyword',
        paste('Unsupported body validation keyword:', unknown[[1L]]),
        at = schema_location(source_location, unknown[[1L]])
      )
    }
    for (field in intersect(
      names(body),
      c(
        'minimum',
        'maximum',
        'exclusiveMinimum',
        'exclusiveMaximum',
        'multipleOf',
        'minLength',
        'maxLength',
        'minItems',
        'maxItems',
        'minProperties',
        'maxProperties',
        'uniqueItems',
        'nullable',
        'pattern',
        'enum'
      )
    )) {
      value <- body[[field]]
      boolean <- field %in%
        c('uniqueItems', 'nullable') ||
        (field %in%
          c('exclusiveMinimum', 'exclusiveMaximum') &&
          !startsWith(document$openapi %or% '', '3.1'))
      valid <- if (boolean) {
        is.logical(value) && length(value) == 1L && !is.na(value)
      } else if (field == 'pattern') {
        is.character(value) && length(value) == 1L && !is.na(value)
      } else if (field == 'enum') {
        is.list(value) && is.null(names(value))
      } else {
        is.numeric(value) && length(value) == 1L && is.finite(value)
      }
      if (
        valid &&
          field %in%
            c(
              'minLength',
              'maxLength',
              'minItems',
              'maxItems',
              'minProperties',
              'maxProperties'
            )
      ) {
        valid <- value >= 0 && value == trunc(value)
      }
      if (valid && field == 'multipleOf') {
        valid <- value > 0
      }
      if (!valid) {
        fail(
          'invalid_constraint',
          paste('Invalid body constraint:', field),
          'schema_defect',
          schema_location(source_location, field)
        )
      }
    }
  }
  recurse <- function(schema, at) {
    supported_body(schema, document, seen, at, allow_composition, composed)
  }
  if (is.list(body$items)) {
    body$items <- recurse(body$items, schema_location(source_location, 'items'))
  }
  if (is.list(body$additionalProperties)) {
    body$additionalProperties <- recurse(
      body$additionalProperties,
      schema_location(source_location, 'additionalProperties')
    )
  }
  if (is.list(body$properties)) {
    if (
      is.null(names(body$properties)) || any(!nzchar(names(body$properties)))
    ) {
      fail('invalid_properties', 'Invalid body properties', 'schema_defect')
    }
    body$properties <- stats::setNames(
      lapply(names(body$properties), function(name) {
        recurse(
          body$properties[[name]],
          schema_location(schema_location(source_location, 'properties'), name)
        )
      }),
      names(body$properties)
    )
  }
  for (field in composition) {
    branches <- body[[field]]
    if (!is.list(branches) || !length(branches) || !is.null(names(branches))) {
      fail('invalid_composition', 'Invalid body composition', 'schema_defect')
    }
    body[[field]] <- lapply(seq_along(branches), function(i) {
      recurse(
        branches[[i]],
        schema_location(schema_location(source_location, field), i - 1L)
      )
    })
  }
  type <- unlist(body$type, use.names = FALSE)
  if (!composed && !length(type) && length(body$properties)) {
    body$type <- 'object'
    type <- 'object'
  }
  if ('array' %in% type && is.null(body$items)) {
    body$items <- list()
  }
  if ('object' %in% type) {
    required <- unlist(body$required, use.names = FALSE)
    if (
      length(required) &&
        (!is.character(required) ||
          (isFALSE(body$additionalProperties) &&
            any(!required %in% names(body$properties))))
    ) {
      fail('invalid_required', 'Invalid required body fields', 'schema_defect')
    }
  }
  if (
    !composed &&
      !length(type) &&
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
  }
  if (!composed && !length(type)) {
    fail('body_shape', 'Unsupported body shape')
  }
  if (!allow_composition && (length(type) != 1L || identical(type, 'null'))) {
    fail('body_shape', 'Unsupported body shape')
  }
  if (
    length(type) &&
      any(
        !type %in%
          c('string', 'integer', 'number', 'boolean', 'object', 'array', 'null')
      )
  ) {
    fail('body_shape', 'Unsupported body shape')
  }
  body
}

body_fixture <- function(schema, override = NULL) {
  if (!missing(override)) {
    return(body_value(override, schema))
  }
  for (candidate in body_fixture_candidates(schema)) {
    result <- tryCatch(
      list(ok = TRUE, value = body_value(candidate, schema)),
      error = function(e) list(ok = FALSE)
    )
    if (result$ok) return(result$value)
  }
  stop('No valid body fixture: supply a reviewed override', call. = FALSE)
}

body_fixture_candidates <- function(schema) {
  direct <- c(
    if ('const' %in% names(schema)) list(schema$const),
    if ('example' %in% names(schema)) list(schema$example),
    if ('default' %in% names(schema)) list(schema$default),
    if (length(schema$enum)) as.list(schema$enum)
  )
  fields <- intersect(names(schema), c('oneOf', 'anyOf', 'allOf'))
  if (length(fields)) {
    by_field <- lapply(schema[fields], function(branches) {
      lapply(branches, body_fixture_candidates)
    })
    candidates <- unlist(
      unlist(by_field, recursive = FALSE),
      recursive = FALSE
    )
    if ('allOf' %in% fields) {
      first <- lapply(by_field$allOf, function(values) {
        if (length(values)) values[[1L]] else NULL
      })
      if (
        all(vapply(
          first,
          function(x) is.list(x) && !is.null(names(x)),
          logical(1)
        ))
      ) {
        merged <- stats::setNames(list(), character())
        for (value in first) {
          merged <- utils::modifyList(merged, value, keep.null = TRUE)
        }
        candidates <- c(list(merged), candidates)
      }
    }
    plain <- tryCatch(body_fixture_plain(schema), error = function(e) list())
    return(c(direct, candidates, plain))
  }
  c(direct, tryCatch(body_fixture_plain(schema), error = function(e) list()))
}

body_fixture_plain <- function(schema) {
  type <- unlist(schema$type, use.names = FALSE)
  if (!length(type)) {
    return(list(list()))
  }
  if ('null' %in% type) {
    return(list(NULL))
  }
  if ('array' %in% type) {
    return(list(lapply(seq_len(schema$minItems %or% 1L), function(i) {
      body_fixture_value(schema$items)
    })))
  }
  if ('object' %in% type) {
    keys <- union(names(schema$properties), unlist(schema$required)) %or%
      character()
    return(list(stats::setNames(
      lapply(keys, function(name) {
        body_fixture_value(
          schema$properties[[name]] %or%
            if (is.list(schema$additionalProperties)) {
              schema$additionalProperties
            } else {
              list()
            }
        )
      }),
      keys
    )))
  }
  list(fixture_value(schema))
}

body_fixture_value <- function(schema, override = NULL) {
  if (!missing(override)) {
    return(override)
  }
  body_fixture(schema)
}

# Self-contained: generated clients need no specmill runtime or new helper argument.
body_value <- function(value, schema) {
  equal_json <- function(x, y) {
    if (is.list(x) || is.list(y)) {
      if (
        !is.list(x) ||
          !is.list(y) ||
          !identical(is.null(names(x)), is.null(names(y)))
      ) {
        return(FALSE)
      }
      if (is.null(names(x))) {
        return(length(x) == length(y) && all(mapply(equal_json, x, y)))
      }
      if (!setequal(names(x), names(y))) {
        return(FALSE)
      }
      return(all(vapply(
        sort(names(x)),
        function(name) equal_json(x[[name]], y[[name]]),
        logical(1)
      )))
    }
    if (is.numeric(x) && is.numeric(y)) {
      return(
        length(x) == 1L && length(y) == 1L && !is.na(x) && !is.na(y) && x == y
      )
    }
    identical(x, y)
  }
  validate <- function(value, schema, strict = FALSE) {
    type <- unlist(schema$type, use.names = FALSE)
    strict <- strict ||
      length(type) > 1L ||
      any(c('oneOf', 'anyOf', 'allOf') %in% names(schema))
    if (is.object(value) || !is.null(dim(value))) {
      stop('Body must contain plain JSON values')
    }
    scalar <- is.atomic(value) &&
      length(value) == 1L &&
      !anyNA(value) &&
      is.null(names(value))
    shape <- if (is.null(value)) {
      'null'
    } else if (is.list(value)) {
      if (is.null(names(value))) 'array' else 'object'
    } else if (!scalar) {
      ''
    } else if (is.character(value)) {
      'string'
    } else if (is.logical(value)) {
      'boolean'
    } else if (is.numeric(value) && is.finite(value) && value == trunc(value)) {
      'integer'
    } else if (is.numeric(value) && is.finite(value)) {
      'number'
    } else {
      ''
    }
    if (!nzchar(shape)) {
      stop('Invalid body scalar type')
    }
    legacy_empty_object <- !strict &&
      identical(shape, 'array') &&
      !length(value) &&
      identical(type, 'object')
    if (
      shape != 'null' &&
        length(type) &&
        !legacy_empty_object &&
        !(shape %in% type || (shape == 'integer' && 'number' %in% type))
    ) {
      stop('Invalid body scalar type')
    }
    if (shape == 'null') {
      if (length(type) && !('null' %in% type) && !isTRUE(schema$nullable)) {
        stop('Explicit null body is not nullable')
      }
    } else if (shape == 'object' || legacy_empty_object) {
      keys <- names(value)
      if (is.null(keys)) {
        keys <- character()
      }
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
        child <- schema$properties[[keys[[i]]]]
        if (is.null(child)) {
          child <- if (is.list(schema$additionalProperties)) {
            schema$additionalProperties
          } else {
            list()
          }
        }
        validate(value[[i]], child, strict)
      })
      names(value) <- keys
    } else if (shape == 'array') {
      if (
        (!is.null(schema$minItems) && length(value) < schema$minItems) ||
          (!is.null(schema$maxItems) && length(value) > schema$maxItems)
      ) {
        stop('Invalid body array length')
      }
      value <- lapply(value, validate, schema = schema$items, strict = strict)
    }
    numeric_value <- shape %in% c('integer', 'number')
    if (
      numeric_value &&
        ((!is.null(schema$minimum) && value < schema$minimum) ||
          (!is.null(schema$maximum) && value > schema$maximum) ||
          (isTRUE(schema$exclusiveMinimum) &&
            !is.null(schema$minimum) &&
            value <= schema$minimum) ||
          (isTRUE(schema$exclusiveMaximum) &&
            !is.null(schema$maximum) &&
            value >= schema$maximum) ||
          (!is.null(schema$exclusiveMinimum) &&
            is.numeric(schema$exclusiveMinimum) &&
            value <= schema$exclusiveMinimum) ||
          (!is.null(schema$exclusiveMaximum) &&
            is.numeric(schema$exclusiveMaximum) &&
            value >= schema$exclusiveMaximum))
    ) {
      stop('Invalid body numeric bounds')
    }
    if (
      numeric_value &&
        !is.null(schema$multipleOf) &&
        abs(value / schema$multipleOf - round(value / schema$multipleOf)) >
          sqrt(.Machine$double.eps)
    ) {
      stop('Invalid body multipleOf')
    }
    if (
      shape == 'string' &&
        ((!is.null(schema$minLength) && nchar(value) < schema$minLength) ||
          (!is.null(schema$maxLength) && nchar(value) > schema$maxLength) ||
          (!is.null(schema$pattern) &&
            !grepl(schema$pattern, value, perl = TRUE)))
    ) {
      stop('Invalid body string')
    }
    if (
      !is.null(schema$enum) &&
        !any(vapply(schema$enum, equal_json, logical(1), y = value))
    ) {
      stop('Invalid body enum')
    }
    if ('const' %in% names(schema) && !equal_json(value, schema$const)) {
      stop('Invalid body const')
    }
    if (
      ((!is.null(schema$minProperties) &&
        is.list(value) &&
        !is.null(names(value)) &&
        length(value) < schema$minProperties) ||
        (!is.null(schema$maxProperties) &&
          is.list(value) &&
          !is.null(names(value)) &&
          length(value) > schema$maxProperties))
    ) {
      stop('Invalid body object size')
    }
    # ponytail: O(n^2) JSON equality; add canonical hashing only if large unique arrays matter.
    if (
      isTRUE(schema$uniqueItems) &&
        shape == 'array' &&
        any(vapply(
          seq_along(value),
          function(i) {
            any(vapply(
              value[seq_len(i - 1L)],
              equal_json,
              logical(1),
              y = value[[i]]
            ))
          },
          logical(1)
        ))
    ) {
      stop('Duplicate body array items')
    }
    for (field in c('allOf', 'anyOf', 'oneOf')) {
      if (!field %in% names(schema)) {
        next
      }
      branches <- schema[[field]]
      if (is.null(branches)) {
        branches <- list()
      }
      matches <- vapply(
        branches,
        function(branch) {
          !inherits(
            try(validate(value, branch, TRUE), silent = TRUE),
            'try-error'
          )
        },
        logical(1)
      )
      if (field == 'allOf' && !all(matches)) {
        stop('Body allOf requires every branch')
      }
      if (field == 'anyOf' && !any(matches)) {
        stop('Body anyOf matched no branches')
      }
      if (field == 'oneOf' && sum(matches) != 1L) {
        stop(
          'Body oneOf matched ',
          sum(matches),
          ' branches; expected exactly one'
        )
      }
    }
    value
  }
  validate(value, schema)
}

body_checks <- function(schema, value) {
  paste0(
    value,
    ' <- base::evalq(',
    r_literal(body_value),
    ', envir = base::baseenv())(',
    value,
    ', ',
    r_literal(schema),
    ')'
  )
}
