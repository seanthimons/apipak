composition_constraints_acceptance <- function() {
  validate <- getFromNamespace('body_value', 'specmill')
  normalize <- getFromNamespace('supported_body', 'specmill')
  fixture <- getFromNamespace('body_fixture', 'specmill')
  fails <- function(expr) {
    stopifnot(inherits(tryCatch(force(expr), error = identity), 'error'))
  }
  empty <- stats::setNames(list(), character())
  deep <- list(type = 'integer')
  for (i in seq_len(25L)) {
    deep <- list(allOf = list(deep))
  }
  stopifnot(identical(fixture(deep), 1L))
  for (schema in list(
    list(type = c('object', 'string'), not = list()),
    list(
      type = 'object',
      not = list(),
      properties = list(x = list(anyOf = list(list(type = 'string'))))
    )
  )) {
    error <- tryCatch(
      normalize(schema, list(openapi = '3.1.0')),
      error = identity
    )
    stopifnot(identical(error$code, 'body_keyword'))
  }
  for (constraint in list(
    list(exclusiveMinimum = 'bad'),
    list(minimum = NULL),
    list(multipleOf = 0),
    list(minItems = -1),
    list(uniqueItems = 'false'),
    list(nullable = 'false')
  )) {
    error <- tryCatch(
      normalize(c(list(type = 'number'), constraint), list(openapi = '3.0.3')),
      error = identity
    )
    stopifnot(identical(error$code, 'invalid_constraint'))
  }
  strict_types <- normalize(
    list(
      type = c('object', 'string'),
      properties = list(x = list(type = 'object'))
    ),
    list(openapi = '3.1.0')
  )
  fails(validate(list(x = list()), strict_types))
  stopifnot(identical(
    fixture(list(
      example = 'valid',
      allOf = list(
        list(type = 'string', pattern = '^valid$'),
        list(minLength = 5L)
      )
    )),
    'valid'
  ))
  stopifnot(identical(
    fixture(list(
      type = 'object',
      properties = list(
        value = list(
          anyOf = list(
            list(type = 'string', pattern = '^valid$', example = 'invalid'),
            list(type = 'integer')
          )
        )
      )
    )),
    list(value = 1L)
  ))

  # Null remains a JSON value subject to every applicable assertion.
  stopifnot(is.null(validate(NULL, list(type = 'null', enum = list(NULL)))))
  fails(validate(NULL, list(type = 'null', enum = list('x'))))
  stopifnot(is.null(validate(NULL, list(type = 'null', const = NULL))))
  fails(validate(NULL, list(type = 'null', const = 'x')))
  stopifnot(is.null(validate(NULL, list(type = 'string', nullable = TRUE))))
  stopifnot(is.null(validate(
    NULL,
    list(oneOf = list(list(type = 'null'), list(type = 'string')))
  )))
  fails(validate(
    NULL,
    list(
      type = 'null',
      oneOf = list(list(type = 'null'), list(enum = list(NULL)))
    )
  ))
  stopifnot(identical(
    validate(empty, list(anyOf = list(list(type = 'object')))),
    empty
  ))
  fails(validate(list(), list(anyOf = list(list(type = 'object')))))

  # Keywords without a type constrain compatible JSON shapes only.
  stopifnot(identical(
    validate(1L, list(properties = list(id = list(type = 'string')))),
    1L
  ))
  stopifnot(identical(
    validate(
      'x',
      list(
        type = list('object', 'string'),
        properties = list(id = list(type = 'integer'))
      )
    ),
    'x'
  ))
  stopifnot(identical(
    validate(
      list(id = 1L),
      list(
        type = list('object', 'string'),
        required = list('id'),
        properties = list(id = list(type = 'integer'))
      )
    ),
    list(id = 1L)
  ))
  fails(validate(
    list(),
    list(
      type = 'object',
      required = list('id'),
      additionalProperties = list(type = 'integer'),
      properties = list(id = list(type = 'string'))
    )
  ))
  fails(validate(
    list(id = 'x', count = 'bad'),
    list(
      type = 'object',
      additionalProperties = list(type = 'integer'),
      properties = list(id = list(type = 'string'))
    )
  ))
  fails(validate(1L, list(type = 'string', minimum = 2L)))
  stopifnot(identical(
    validate('x', list(type = 'string', minimum = 2L, maxLength = 1L)),
    'x'
  ))
  fails(validate(c('x', 'y'), list(type = 'string')))
  fails(validate(NA_character_, list(type = 'string')))
  fails(validate(stats::setNames('x', 'named'), list(type = 'string')))

  # JSON equality is structural: object keys are unordered, 1L equals 1, and {} differs from [].
  stopifnot(identical(
    validate(list(a = 1L, b = 2L), list(enum = list(list(b = 2, a = 1)))),
    list(a = 1L, b = 2L)
  ))
  stopifnot(identical(validate(empty, list(enum = list(empty))), empty))
  fails(validate(empty, list(enum = list(list()))))
  fails(validate(
    list(list(a = 1L, b = 2L), list(b = 2, a = 1)),
    list(type = 'array', uniqueItems = TRUE)
  ))

  # Integer is also number, so this oneOf must reject an integer but accept a fraction.
  fails(validate(
    1L,
    list(oneOf = list(list(type = 'integer'), list(type = 'number')))
  ))
  stopifnot(identical(
    validate(
      1.5,
      list(oneOf = list(list(type = 'integer'), list(type = 'number')))
    ),
    1.5
  ))
  repeated <- rep(list(list(type = 'string')), 100L)
  fails(validate('x', list(oneOf = repeated)))
  stopifnot(identical(validate('x', list(anyOf = repeated)), 'x'))

  # OpenAPI 3.0 boolean and 3.1 numeric exclusive bounds both remain accepted.
  stopifnot(identical(
    validate(2L, list(type = 'integer', minimum = 1L, exclusiveMinimum = TRUE)),
    2L
  ))
  fails(validate(
    1L,
    list(type = 'integer', minimum = 1L, exclusiveMinimum = TRUE)
  ))
  stopifnot(identical(
    validate(2L, list(type = 'integer', exclusiveMinimum = 1L)),
    2L
  ))
  fails(validate(1L, list(type = 'integer', exclusiveMinimum = 1L)))

  unknown <- tryCatch(
    normalize(list(oneOf = list(list(not = list(type = 'string')))), list()),
    error = identity
  )
  stopifnot(inherits(unknown, 'error'), identical(unknown$code, 'body_keyword'))
  malformed <- tryCatch(
    normalize(list(anyOf = list()), list()),
    error = identity
  )
  stopifnot(
    inherits(malformed, 'error'),
    identical(malformed$code, 'invalid_composition')
  )
  typeless_branch <- normalize(
    list(oneOf = list(list(properties = list(id = list(type = 'integer'))))),
    list()
  )
  stopifnot(is.null(typeless_branch$oneOf[[1L]]$type))
  form_gate <- tryCatch(
    normalize(
      list(
        type = 'object',
        properties = list(
          value = list(
            anyOf = list(list(type = 'string'), list(type = 'integer'))
          )
        )
      ),
      list(),
      allow_composition = FALSE
    ),
    error = identity
  )
  stopifnot(
    inherits(form_gate, 'error'),
    identical(form_gate$code, 'body_composition')
  )
  null_form_gate <- tryCatch(
    normalize(list(type = 'null'), list(), allow_composition = FALSE),
    error = identity
  )
  stopifnot(
    inherits(null_form_gate, 'error'),
    identical(null_form_gate$code, 'body_shape')
  )
  cat(
    'Composition constraints: null assertions, JSON equality, shape-aware keywords, exclusive bounds and diagnostics passed.\n'
  )
}

if (sys.nframe() == 0L) {
  composition_constraints_acceptance()
}
