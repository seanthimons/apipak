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
  root <- tempfile('media-config-')
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  payload <- list(
    type = 'object',
    required = list('name'),
    properties = list(name = list(type = 'string'))
  )
  operation <- function(name, content) {
    list(
      operationId = name,
      requestBody = list(required = TRUE, content = content),
      responses = list('200' = list(description = 'OK'))
    )
  }
  configured <- list(
    openapi = '3.0.3',
    info = list(title = 'Configured media', version = '1'),
    servers = list(list(url = 'https://media.invalid')),
    paths = list(
      '/default' = list(
        post = operation(
          'default_form',
          list(
            'application/json' = list(schema = payload),
            'application/x-www-form-urlencoded' = list(schema = payload),
            'multipart/form-data' = list(schema = payload)
          )
        )
      ),
      '/override' = list(
        post = operation(
          'override_multipart',
          list(
            'application/json' = list(schema = payload),
            'application/x-www-form-urlencoded' = list(schema = payload),
            'multipart/form-data' = list(schema = payload)
          )
        )
      ),
      '/json' = list(
        post = operation(
          'json_default',
          list(
            'application/json' = list(schema = payload),
            'application/x-www-form-urlencoded' = list(schema = payload)
          )
        )
      ),
      '/invalid' = list(
        post = operation(
          'invalid_override',
          list(
            'application/json' = list(schema = payload)
          )
        )
      )
    )
  )
  schema <- file.path(root, 'schema.json')
  jsonlite::write_json(configured, schema, auto_unbox = TRUE)
  specmill::initialize_client(
    root,
    schema,
    package = 'mediaconfig',
    title = 'Configured media',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'test@example.org'
    ),
    license = 'MIT + file LICENSE'
  )
  service_path <- file.path(root, 'apis', 'default.yml')
  service <- yaml::read_yaml(service_path, handlers = list(seq = function(x) x))
  service$defaults$body_media <- 'application/x-www-form-urlencoded'
  service$operations[['POST /override']] <- list(
    body_media = 'multipart/form-data'
  )
  service$operations[['POST /json']] <- list(body_media = 'application/json')
  service$operations[['POST /invalid']] <- list(
    body_media = 'multipart/form-data'
  )
  yaml::write_yaml(service, service_path)
  project <- specmill::load_project(root)
  selected <- project$services$mediaconfig
  parsed <- specmill::read_operations(selected$files, selected$policy)
  by_key <- function(records, key) {
    Filter(
      function(x) identical(x$key, key),
      records
    )[[1L]]
  }
  stopifnot(
    identical(
      by_key(parsed$operations, 'POST /default')$body_media,
      'application/x-www-form-urlencoded'
    ),
    identical(
      by_key(parsed$operations, 'POST /override')$body_media,
      'multipart/form-data'
    ),
    identical(
      by_key(parsed$operations, 'POST /json')$body_media,
      'application/json'
    ),
    identical(
      by_key(parsed$diagnostics, 'POST /invalid')$code,
      'body_media_type'
    )
  )
  service$operations[['POST /invalid']] <- list(
    body_media = 'application/json'
  )
  yaml::write_yaml(service, service_path)
  helper <- file.path(root, 'R', 'api_request.R')
  writeLines(
    'api_request <- function(method, path, path_params, query, body) NULL',
    helper
  )
  before <- tools::md5sum(helper)
  error <- tryCatch(
    specmill::generate_client(root, config = 'specmill.yml', mode = 'plan'),
    error = identity
  )
  stopifnot(
    inherits(error, 'error'),
    grepl('body_media', conditionMessage(error)),
    identical(before, tools::md5sum(helper))
  )
  service$operations[['POST /invalid']] <- list(body_media = 'text/plain')
  yaml::write_yaml(service, service_path)
  invalid <- tryCatch(specmill::load_project(root), error = identity)
  stopifnot(
    inherits(invalid, 'error'),
    grepl('Unsupported body_media', conditionMessage(invalid))
  )
  cat(
    'Media selection: JSON alternatives, configured form defaults and overrides, helper diagnostics, references and unsupported-only bodies passed.\n'
  )
}
if (sys.nframe() == 0L) {
  media_type_acceptance()
}
