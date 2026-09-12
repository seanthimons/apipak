schema_version_acceptance <- function() {
  file <- tempfile(fileext = '.json')
  scalar_array <- list(
    type = 'array',
    items = list(type = 'string'),
    minItems = 1L
  )
  object_array <- list(
    type = 'array',
    items = list(
      type = 'object',
      required = list('title'),
      properties = list(title = list(type = 'string'))
    )
  )
  for (version in c('3.0.3', '3.1.0', '2.0')) {
    for (shape in list(scalar_array, object_array)) {
      op <- list(
        operationId = 'submit_items',
        responses = list('200' = list(description = 'ok'))
      )
      schema <- list(info = list(title = 'Arrays', version = '1'))
      if (version == '2.0') {
        schema$swagger <- version
        schema$consumes <- list('application/json')
        schema$definitions <- list(Payload = shape)
        op$parameters <- list(list(
          name = 'body',
          'in' = 'body',
          required = TRUE,
          schema = list('$ref' = '#/definitions/Payload')
        ))
      } else {
        schema$openapi <- version
        schema$components <- list(schemas = list(Payload = shape))
        op$requestBody <- list(
          required = TRUE,
          content = list(
            'application/json' = list(
              schema = list('$ref' = '#/components/schemas/Payload')
            )
          )
        )
      }
      schema$paths <- list('/items' = list(post = op))
      jsonlite::write_json(schema, file, auto_unbox = TRUE)
      parsed <- specmill::read_operations(file)
      stopifnot(length(parsed$operations) == 1L, !length(parsed$diagnostics))
      operation <- parsed$operations$submit_items
      stopifnot(
        operation$route == '/items',
        operation$method == 'POST',
        operation$schema_version == version,
        !is.null(operation$body_schema_full)
      )
      context <- new.env(parent = baseenv())
      context$request_helper <- function(...) list(...)
      eval(
        parse(
          text = specmill::render_operation(
            operation,
            list(helper = 'request_helper')
          )
        ),
        envir = context
      )
      body <- if (shape$items$type == 'string') {
        list('first', 'second')
      } else {
        list(list(title = 'first'), list(title = 'second'))
      }
      expected <- list(
        method = 'POST',
        path = '/items',
        path_params = list(),
        query = list(),
        body = body
      )
      stopifnot(identical(context$submit_items(body), expected))
      if (shape$items$type == 'object') {
        stopifnot(inherits(
          try(context$submit_items(list(list())), silent = TRUE),
          'try-error'
        ))
      }
      fixtures <- specmill::operation_fixtures(parsed$operations)
      stopifnot(
        is.list(fixtures$submit_items$body),
        length(fixtures$submit_items$body) == 1L
      )
    }
  }
  unsupported <- jsonlite::fromJSON(
    system.file('catalogue/schema.json', package = 'specmill'),
    simplifyVector = FALSE
  )
  for (location in c('cookie', 'formData')) {
    unsupported$paths[['/items/{item_id}']]$get$parameters[[2L]][[
      'in'
    ]] <- location
    jsonlite::write_json(unsupported, file, auto_unbox = TRUE)
    parsed <- specmill::read_operations(file)
    if (location == 'cookie') {
      stopifnot(!length(parsed$diagnostics))
      next
    }
    stopifnot(
      length(parsed$diagnostics) == 1L,
      parsed$diagnostics[[1L]]$key == 'GET /items/{item_id}',
      grepl('location', parsed$diagnostics[[1L]]$reason)
    )
  }
  cat(
    'OpenAPI 3.0/3.1 and Swagger 2: scalar/object JSON arrays, required fields, fixtures and header/cookie diagnostics passed.\n'
  )
}
if (sys.nframe() == 0L) {
  schema_version_acceptance()
}
