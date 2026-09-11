media_type_acceptance <- function() {
  file <- tempfile(fileext = '.json')
  on.exit(unlink(file), add = TRUE)
  for (version in c('3.0.3', '3.1.0')) {
    content <- list(
      'application/xml' = list(schema = list(type = 'string')),
      'application/json' = list(
        schema = list('$ref' = '#/components/schemas/Payload')
      ),
      'application/x-www-form-urlencoded' = list(schema = list(type = 'string'))
    )
    document <- list(
      openapi = version,
      info = list(title = 'Media selection', version = '1'),
      components = list(
        schemas = list(
          Payload = list(
            type = 'object',
            required = list('name'),
            properties = list(name = list(type = 'string'))
          )
        )
      ),
      paths = list(
        '/items' = list(
          post = list(
            operationId = 'create_item',
            requestBody = list(required = TRUE, content = content),
            responses = list('200' = list(description = 'OK'))
          )
        )
      )
    )
    for (choices in list(content, rev(content), content['application/json'])) {
      document$paths[['/items']]$post$requestBody$content <- choices
      jsonlite::write_json(document, file, auto_unbox = TRUE)
      parsed <- specmill::read_operations(file)
      stopifnot(!length(parsed$diagnostics), length(parsed$operations) == 1L)
      operation <- parsed$operations[[1L]]
      stopifnot(operation$body$type == 'object', operation$body_required)
      context <- new.env(parent = baseenv())
      context$request_helper <- function(...) list(...)
      eval(
        parse(
          text = specmill::render_operation(
            operation,
            list(helper = 'request_helper')
          )
        ),
        context
      )
      stopifnot(
        identical(
          context$create_item(list(name = 'Milo'))$body,
          list(name = 'Milo')
        ),
        inherits(try(context$create_item(list()), silent = TRUE), 'try-error')
      )
    }
    for (choices in list(
      content['application/xml'],
      list(
        'application/octet-stream' = list(
          schema = list(type = 'string')
        )
      )
    )) {
      document$paths[['/items']]$post$requestBody$content <- choices
      jsonlite::write_json(document, file, auto_unbox = TRUE)
      parsed <- specmill::read_operations(file)
      stopifnot(
        length(parsed$diagnostics) == 1L,
        parsed$diagnostics[[1L]]$reason %in%
          c('Unsupported body media type', 'Unsupported binary body schema')
      )
    }
  }
  cat(
    'Media selection: JSON alternatives, order independence, references, required fields and unsupported-only bodies passed.\n'
  )
}
if (sys.nframe() == 0L) {
  media_type_acceptance()
}
