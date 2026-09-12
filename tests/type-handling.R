type_handling_acceptance <- function() {
  type_is <- getFromNamespace('schema_type_is', 'specmill')
  stopifnot(
    type_is('object', 'object'),
    !type_is(NA_character_, 'object'),
    !type_is(c('object', 'null'), 'object'),
    !type_is(NULL, 'object')
  )

  records_for <- getFromNamespace('endpoint_records', 'specmill')
  document <- list(
    openapi = '3.1.0',
    paths = list(
      '/nullable-response' = list(
        get = list(
          operationId = 'nullable_response',
          responses = list(
            '200' = list(
              description = 'ok',
              content = list(
                'application/json' = list(
                  schema = list(
                    type = c('string', 'null')
                  )
                )
              )
            )
          )
        )
      ),
      '/missing-type' = list(
        post = list(
          operationId = 'missing_type',
          requestBody = list(
            content = list(
              'application/json' = list(
                schema = list(
                  properties = list(value = list(type = 'string'))
                )
              )
            )
          ),
          responses = list('200' = list(description = 'ok'))
        )
      )
    )
  )
  compatibility <- records_for(
    document,
    list(
      list(
        key = 'GET /nullable-response',
        method = 'GET',
        path = '/nullable-response'
      ),
      list(key = 'POST /missing-type', method = 'POST', path = '/missing-type')
    )
  )
  stopifnot(
    length(compatibility) == 2L,
    compatibility[[1L]]$response_schema_type == 'unknown',
    compatibility[[2L]]$body_schema_type == 'unknown'
  )

  fallback_document <- document
  fallback_document$paths[['/parser-failure']] <- list(
    get = list(
      operationId = 'parser_failure',
      deprecated = c(TRUE, FALSE),
      responses = list('200' = list(description = 'ok'))
    )
  )
  fallback <- records_for(
    fallback_document,
    list(
      list(
        key = 'GET /nullable-response',
        method = 'GET',
        path = '/nullable-response'
      ),
      list(
        key = 'GET /parser-failure',
        method = 'GET',
        path = '/parser-failure'
      )
    )
  )
  stopifnot(
    fallback[[1L]]$response_schema_type == 'unknown',
    nzchar(fallback[[2L]]$parser_failure),
    identical(
      attr(fallback, 'parser_diagnostics')[[1L]]$key,
      'GET /parser-failure'
    )
  )

  file <- tempfile(fileext = '.json')
  on.exit(unlink(file), add = TRUE)
  document$paths[['/nullable-parameter']] <- list(
    get = list(
      operationId = 'nullable_parameter',
      parameters = list(list(
        name = 'filter',
        'in' = 'query',
        schema = list(type = c('string', 'null'))
      )),
      responses = list('200' = list(description = 'ok'))
    )
  )
  document$paths[['/parser-failure']] <- fallback_document$paths[[
    '/parser-failure'
  ]]
  jsonlite::write_json(document, file, auto_unbox = TRUE)
  parsed <- specmill::read_operations(file)
  stopifnot(
    identical(
      sort(names(parsed$operations)),
      c('missing_type', 'nullable_response')
    ),
    length(parsed$diagnostics) == 2L,
    any(vapply(
      parsed$diagnostics,
      function(x) {
        identical(x$key, 'GET /nullable-parameter') &&
          identical(x$code, 'parameter_shape')
      },
      logical(1)
    )),
    any(vapply(
      parsed$diagnostics,
      function(x) {
        identical(x$key, 'GET /parser-failure') &&
          identical(x$code, 'parser_failure')
      },
      logical(1)
    ))
  )
  cat(
    'Type handling: absent and union types retain metadata, diagnose unsupported inputs, and do not abort sibling operations.\n'
  )
}

if (sys.nframe() == 0L) {
  type_handling_acceptance()
}
