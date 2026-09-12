composition_transport_acceptance <- function() {
  native <- if (file.exists('tests/native-transport.R')) {
    'tests/native-transport.R'
  } else {
    'native-transport.R'
  }
  source(native, local = TRUE)
  native_transport_acceptance(function(runtime, root) {
    empty <- stats::setNames(list(), character())
    branch_a <- list(
      type = 'object',
      additionalProperties = FALSE,
      required = list('tag', 'a'),
      properties = list(
        tag = list(type = 'string', enum = list('a')),
        a = list(type = 'integer')
      )
    )
    branch_b <- list(
      type = 'object',
      additionalProperties = FALSE,
      required = list('tag', 'b'),
      properties = list(
        tag = list(type = 'string', enum = list('b')),
        b = list(type = 'string')
      )
    )
    schemas <- list(
      one = list(
        oneOf = list(
          list('$ref' = '#/components/schemas/A'),
          list('$ref' = '#/components/schemas/B')
        )
      ),
      overlap_one = list(
        oneOf = list(
          list(type = 'object'),
          list(type = 'object', required = list('id'))
        )
      ),
      overlap_any = list(
        anyOf = list(
          list(type = 'object'),
          list(type = 'object', required = list('id'))
        )
      ),
      numeric_one = list(
        oneOf = list(list(type = 'integer'), list(type = 'number'))
      ),
      sibling = list(
        type = 'object',
        required = list('id'),
        additionalProperties = list(type = 'integer'),
        properties = list(id = list(type = 'string')),
        anyOf = list(list(type = 'object'))
      ),
      typeless_sibling = list(
        required = list('id'),
        properties = list(id = list(type = 'integer')),
        anyOf = list(list(type = 'object'))
      ),
      nested = list(
        type = 'object',
        required = list('items'),
        properties = list(
          items = list(
            type = 'array',
            items = list(
              oneOf = list(
                list(
                  type = 'object',
                  required = list('x'),
                  properties = list(x = list(type = 'integer'))
                ),
                list(
                  type = 'object',
                  required = list('y'),
                  properties = list(y = list(type = 'string'))
                )
              )
            )
          )
        )
      ),
      representative = list(
        oneOf = list(
          list(
            type = 'object',
            required = list('values'),
            properties = list(
              values = list(type = 'array', items = list(type = 'string'))
            )
          ),
          list(
            type = 'object',
            required = list('records'),
            properties = list(
              records = list(
                type = 'array',
                items = list(
                  type = 'object',
                  required = list('id'),
                  properties = list(
                    id = list(
                      anyOf = list(
                        list(type = 'string'),
                        list(type = 'integer')
                      )
                    )
                  )
                )
              )
            )
          )
        )
      ),
      shapes = list(
        oneOf = list(list(type = 'object'), list(type = 'array', items = empty))
      ),
      null31 = list(oneOf = list(list(type = 'null'), list(type = 'string'))),
      all_open = list(
        allOf = list(
          list(
            type = 'object',
            required = list('a'),
            properties = list(a = list(type = 'integer'))
          ),
          list(
            type = 'object',
            required = list('b'),
            properties = list(b = list(type = 'string'))
          )
        )
      ),
      all_closed = list(
        allOf = list(
          list(
            type = 'object',
            required = list('a'),
            additionalProperties = FALSE,
            properties = list(a = list(type = 'integer'))
          ),
          list(type = 'object', required = list('a'))
        )
      ),
      local_ref = list(
        oneOf = list(
          list('$ref' = '#/components/schemas/A'),
          list(type = 'null')
        )
      ),
      ref_sibling = list(
        type = 'object',
        required = list('count'),
        properties = list(
          count = list('$ref' = '#/components/schemas/Integer', maximum = 5L)
        )
      ),
      type_null31 = list(type = list('string', 'null')),
      strict31 = list(type = 'string', nullable = TRUE),
      example_only = list(example = list(tag = 'a', a = 1L)),
      unsupported = list(anyOf = list(list(not = list(type = 'string'))))
    )
    paths <- lapply(names(schemas), function(name) {
      list(
        post = list(
          operationId = paste0('json_', name),
          requestBody = list(
            required = name %in% c('one', 'null31'),
            content = list('application/json' = list(schema = schemas[[name]]))
          ),
          responses = list('200' = list(description = 'OK'))
        )
      )
    })
    names(paths) <- paste0('/', names(schemas))
    document <- list(
      openapi = '3.1.0',
      info = list(title = 'Composition', version = '1'),
      components = list(
        schemas = list(
          A = branch_a,
          B = branch_b,
          Integer = list(type = 'integer', minimum = 1L)
        )
      ),
      paths = paths
    )
    schema <- tempfile(fileext = '.json')
    on.exit(unlink(schema), add = TRUE)
    jsonlite::write_json(document, schema, auto_unbox = TRUE, null = 'null')
    parsed <- specmill::read_operations(schema)
    stopifnot(
      length(parsed$operations) == length(schemas) - 1L,
      length(parsed$diagnostics) == 1L,
      identical(parsed$diagnostics[[1L]]$key, 'POST /unsupported'),
      identical(parsed$diagnostics[[1L]]$code, 'body_keyword')
    )
    for (op in parsed$operations) {
      eval(
        parse(
          text = specmill::render_operation(op, list(helper = 'api_request'))
        ),
        runtime
      )
    }
    nullable <- document
    nullable$openapi <- '3.0.3'
    nullable$paths <- list(
      '/nullable' = list(
        post = list(
          operationId = 'json_nullable30',
          requestBody = list(
            content = list(
              'application/json' = list(
                schema = list(type = 'string', nullable = TRUE)
              )
            )
          ),
          responses = list('200' = list(description = 'OK'))
        )
      )
    )
    jsonlite::write_json(nullable, schema, auto_unbox = TRUE, null = 'null')
    eval(
      parse(
        text = specmill::render_operation(
          specmill::read_operations(schema)$operations[[1L]],
          list(helper = 'api_request')
        )
      ),
      runtime
    )
    wire <- function(result) rawToChar(as.raw(unlist(result$bytes)))
    before <- function() {
      runtime$api_request('GET', '/count', list(), list(), NULL)$request_number
    }
    fails <- function(expr) {
      stopifnot(inherits(tryCatch(force(expr), error = identity), 'error'))
    }
    stopifnot(
      wire(runtime$json_one(list(tag = 'a', a = 1L))) == '{"tag":"a","a":1}',
      wire(runtime$json_one(list(tag = 'b', b = 'x'))) == '{"tag":"b","b":"x"}',
      wire(runtime$json_overlap_any(list(id = 1L))) == '{"id":1}',
      wire(runtime$json_numeric_one(1.5)) == '1.5',
      wire(runtime$json_sibling(list(id = 'x', count = 2L))) ==
        '{"id":"x","count":2}',
      wire(runtime$json_typeless_sibling(list(id = 1L))) == '{"id":1}',
      wire(runtime$json_nested(list(
        items = list(list(x = 1L), list(y = 'x'))
      ))) ==
        '{"items":[{"x":1},{"y":"x"}]}',
      wire(runtime$json_shapes(empty)) == '{}',
      wire(runtime$json_shapes(list())) == '[]',
      wire(runtime$json_representative(list(values = list('x')))) ==
        '{"values":["x"]}',
      wire(runtime$json_representative(list(records = list(list(id = 1L))))) ==
        '{"records":[{"id":1}]}',
      wire(runtime$json_null31(NULL)) == 'null',
      wire(runtime$json_nullable30(NULL)) == 'null',
      wire(runtime$json_nullable30()) == '',
      wire(runtime$json_all_open(list(a = 1L, b = 'x'))) == '{"a":1,"b":"x"}',
      wire(runtime$json_all_closed(list(a = 1L))) == '{"a":1}',
      wire(runtime$json_local_ref(list(tag = 'a', a = 1L))) ==
        '{"tag":"a","a":1}',
      wire(runtime$json_example_only(7L)) == '7',
      wire(runtime$json_ref_sibling(list(count = 3L))) == '{"count":3}',
      wire(runtime$json_type_null31(NULL)) == 'null'
    )
    first <- before()
    fails(runtime$json_one(list(tag = 'a', a = 1L, extra = TRUE)))
    fails(runtime$json_one(list(tag = 'b', a = 1L)))
    fails(runtime$json_overlap_one(list(id = 1L)))
    fails(runtime$json_numeric_one(1L))
    fails(runtime$json_sibling(list(id = 1L)))
    fails(runtime$json_sibling(list(id = 'x', count = 'wrong')))
    fails(runtime$json_typeless_sibling(list()))
    fails(runtime$json_nested(list(items = list(list(x = 'wrong')))))
    fails(runtime$json_representative(list(
      values = list('x'),
      records = list(list(id = 'x'))
    )))
    fails(runtime$json_null31())
    fails(runtime$json_null31(1L))
    fails(runtime$json_nullable30(1L))
    fails(runtime$json_all_open(list(a = 1L)))
    fails(runtime$json_all_closed(list(a = 1L, extra = TRUE)))
    fails(runtime$json_local_ref(list(tag = 'b', b = 'x')))
    fails(runtime$json_ref_sibling(list(count = 0L)))
    fails(runtime$json_ref_sibling(list(count = 6L)))
    fails(runtime$json_strict31(NULL))
    stopifnot(before() == first + 1L)
    fixtures <- specmill::operation_fixtures(
      parsed$operations,
      list(
        json_numeric_one = list(body = 1.5),
        json_typeless_sibling = list(body = list(id = 1L)),
        json_one = list(body = list(tag = 'b', b = 'fixture'))
      )
    )
    stopifnot(identical(fixtures$json_one$body, list(tag = 'b', b = 'fixture')))
    fails(specmill::operation_fixtures(
      parsed$operations,
      list(json_overlap_one = list(body = list(id = 1L)))
    ))
    cat(
      'Composition JSON bodies: branch selection, sibling constraints, local refs, nulls, exact bytes and pre-transport failures passed.\n'
    )
  })
}

if (sys.nframe() == 0L) {
  composition_transport_acceptance()
}
