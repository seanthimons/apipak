nested_body_acceptance <- function() {
  fixture <- getFromNamespace('body_fixture', 'specmill')
  normalize <- getFromNamespace('supported_body', 'specmill')
  schema <- list(
    type = 'object',
    required = list('records'),
    properties = list(
      records = list(
        type = 'array',
        minItems = 1L,
        items = list(
          type = 'object',
          required = list('id'),
          properties = list(
            id = list(type = 'integer', minimum = 1L),
            labels = list(type = 'array', items = list(type = 'string'))
          )
        )
      )
    )
  )
  schema <- normalize(schema, list())
  expected <- list(records = list(list(id = 1L, labels = list('example'))))
  stopifnot(
    identical(fixture(schema), expected),
    identical(fixture(schema, expected), expected)
  )
  fails <- function(expr) {
    stopifnot(inherits(tryCatch(force(expr), error = identity), 'error'))
  }
  fails(fixture(
    schema,
    list(records = list(list(labels = list('missing id'))))
  ))
  fails(fixture(schema, list(records = list(list(id = 0L)))))
  fails(fixture(
    schema,
    list(records = list(list(id = 1L, labels = 'wrong array shape')))
  ))
  with_example <- schema
  with_example$example <- list(records = list(list(id = 42L)))
  stopifnot(identical(fixture(with_example), with_example$example))
  document <- list(
    openapi = '3.0.3',
    info = list(title = 'Nested bodies', version = '1'),
    paths = list(
      '/records' = list(
        post = list(
          operationId = 'submit_records',
          requestBody = list(
            required = TRUE,
            content = list('application/json' = list(schema = schema))
          ),
          responses = list('200' = list(description = 'ok'))
        )
      )
    )
  )
  file <- tempfile(fileext = '.json')
  read <- function() {
    jsonlite::write_json(document, file, auto_unbox = TRUE, null = 'null')
    specmill::read_operations(file)
  }
  parsed <- read()
  stopifnot(!length(parsed$diagnostics))
  runtime <- new.env(parent = baseenv())
  calls <- 0L
  runtime$request <- function(...) {
    calls <<- calls + 1L
    list(...)$body
  }
  eval(
    parse(
      text = specmill::render_operation(
        parsed$operations[[1L]],
        list(helper = 'request')
      )
    ),
    runtime
  )
  stopifnot(identical(runtime$submit_records(expected), expected), calls == 1L)
  fails(runtime$submit_records(list(
    records = list(list(labels = list('missing id')))
  )))
  stopifnot(calls == 1L)
  for (value in list('one\ntwo', FALSE, 0)) {
    type <- if (is.character(value)) {
      'string'
    } else if (is.logical(value)) {
      'boolean'
    } else {
      'number'
    }
    document$paths[['/records']]$post$requestBody$content[[
      'application/json'
    ]]$schema <- list(type = type)
    parsed <- read()
    stopifnot(!length(parsed$diagnostics))
    eval(
      parse(
        text = specmill::render_operation(
          parsed$operations[[1L]],
          list(helper = 'request')
        )
      ),
      runtime
    )
    stopifnot(identical(runtime$submit_records(value), value))
  }
  recursive <- list(
    type = 'object',
    properties = list(child = list('$ref' = '#/components/schemas/Node'))
  )
  document$components <- list(schemas = list(Node = recursive))
  document$paths[['/records']]$post$requestBody$content[[
    'application/json'
  ]]$schema <- list('$ref' = '#/components/schemas/Node')
  parsed <- read()
  stopifnot(
    !length(parsed$operations),
    length(parsed$diagnostics) == 1L,
    grepl('cyclic', parsed$diagnostics[[1L]]$reason)
  )
  cat(
    'Nested JSON bodies: recursive fixtures, scalar payloads, nested required fields and cyclic-reference diagnostics passed.\n'
  )
}
if (sys.nframe() == 0L) {
  nested_body_acceptance()
}
