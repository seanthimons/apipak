diagnostics_acceptance <- function() {
  root <- tempfile('diagnostics-')
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  empty <- stats::setNames(list(), character())
  operation <- function(name, schema) {
    list(
      operationId = name,
      tags = list('checks'),
      requestBody = list(
        content = list('application/json' = list(schema = schema))
      ),
      responses = list('200' = list(description = 'OK'))
    )
  }
  document <- list(
    openapi = '3.0.3',
    info = list(title = 'Diagnostics', version = '1'),
    paths = list(
      '/empty' = list(post = operation('empty_body', empty)),
      '/items' = list(
        post = operation('any_items', list(type = 'array', items = empty))
      ),
      '/no-items' = list(post = operation('no_items', list(type = 'array'))),
      '/invalid' = list(post = operation('invalid_type', list(type = 'dict'))),
      '/missing' = list(
        post = operation(
          'missing_ref',
          list('$ref' = '#/components/schemas/Absent')
        )
      ),
      '/external' = list(
        post = operation('external_ref', list('$ref' = 'other.json#/Payload'))
      ),
      '/recursive' = list(
        post = operation(
          'recursive_ref',
          list('$ref' = '#/components/schemas/Node')
        )
      ),
      '/ready' = list(
        post = operation(
          'ready',
          list(type = 'array', items = list(type = 'string'))
        )
      ),
      '/excluded' = list(delete = operation('excluded', list(type = 'dict')))
    ),
    components = list(
      schemas = list(
        Node = list(
          type = 'object',
          properties = list(
            child = list('$ref' = '#/components/schemas/Node')
          )
        )
      )
    )
  )
  document$paths[['/absent']] <- list(post = operation('absent_body', NULL))
  document$paths[['/absent']]$post$requestBody$content[[
    'application/json'
  ]] <- empty
  file <- file.path(root, 'schema.json')
  jsonlite::write_json(document, file, auto_unbox = TRUE)
  policy <- list(methods = c('GET', 'POST'))
  parsed <- specmill::read_operations(file, policy)
  by_key <- function(records, key) {
    found <- Filter(function(x) identical(x$key, key), records)
    stopifnot(length(found) == 1L)
    found[[1L]]
  }
  expected <- list(
    'POST /no-items' = c('schema_defect', 'missing_array_items'),
    'POST /invalid' = c('schema_defect', 'invalid_type'),
    'POST /missing' = c('schema_defect', 'unresolved_reference'),
    'POST /external' = c('capability_gap', 'external_reference'),
    'POST /recursive' = c('capability_gap', 'recursive_reference'),
    'POST /absent' = c('capability_gap', 'missing_schema')
  )
  for (key in names(expected)) {
    diagnostic <- by_key(parsed$diagnostics, key)
    record <- by_key(parsed$inventory, key)
    stopifnot(
      identical(diagnostic$status, 'unsupported'),
      identical(c(diagnostic$classification, diagnostic$code), expected[[key]]),
      startsWith(diagnostic$source_location, '#/'),
      nzchar(diagnostic$guidance),
      identical(record$classification, diagnostic$classification),
      identical(record$source_location, diagnostic$source_location)
    )
  }
  stopifnot(
    by_key(parsed$inventory, 'DELETE /excluded')$classification ==
      'policy_exclusion',
    by_key(parsed$inventory, 'POST /ready')$classification == 'ready',
    by_key(parsed$diagnostics, 'POST /invalid')$source_location ==
      '#/paths/~1invalid/post/requestBody/content/application~1json/schema/type',
    by_key(parsed$diagnostics, 'POST /recursive')$source_location ==
      '#/components/schemas/Node/properties/child',
    by_key(parsed$inventory, 'POST /items')$classification == 'ready'
  )
  # Distinguish version and parameter contexts using the same absent item schema.
  swagger <- list(
    swagger = '2.0',
    info = document$info,
    paths = list(
      '/body' = list(
        post = list(
          operationId = 'body',
          parameters = list(list(
            name = 'payload',
            'in' = 'body',
            schema = list(type = 'array')
          ))
        )
      ),
      '/query' = list(
        get = list(
          operationId = 'query',
          parameters = list(list(
            name = 'values',
            'in' = 'query',
            type = 'array'
          ))
        )
      ),
      '/file' = list(
        post = list(
          operationId = 'file',
          parameters = list(list(
            name = 'file',
            'in' = 'formData',
            type = 'file'
          ))
        )
      )
    )
  )
  swagger_file <- file.path(root, 'swagger.json')
  jsonlite::write_json(swagger, swagger_file, auto_unbox = TRUE)
  swagger_plan <- specmill::read_operations(swagger_file)
  stopifnot(
    by_key(swagger_plan$inventory, 'POST /body')$classification == 'ready',
    by_key(swagger_plan$diagnostics, 'GET /query')$classification ==
      'schema_defect',
    by_key(swagger_plan$diagnostics, 'POST /file')$classification ==
      'capability_gap'
  )
  # Missing items also means unconstrained in 3.1, but not in 3.0.
  newer <- document
  newer$openapi <- '3.1.0'
  newer$paths <- newer$paths['/no-items']
  jsonlite::write_json(newer, swagger_file, auto_unbox = TRUE)
  stopifnot(!length(specmill::read_operations(swagger_file)$diagnostics))
  # Typed map references resolve normally; malformed declarations remain defects.
  newer$components <- list(schemas = list(Value = list(type = 'integer')))
  newer$paths[['/no-items']]$post$requestBody$content[[
    'application/json'
  ]]$schema <-
    list(
      type = 'object',
      additionalProperties = list('$ref' = '#/components/schemas/Value')
    )
  jsonlite::write_json(newer, swagger_file, auto_unbox = TRUE)
  stopifnot(identical(
    specmill::read_operations(swagger_file)$operations[[
      1L
    ]]$body$additionalProperties$type,
    'integer'
  ))
  newer$paths[['/no-items']]$post$requestBody$content[[
    'application/json'
  ]]$schema$additionalProperties <- NULL
  jsonlite::write_json(newer, swagger_file, auto_unbox = TRUE)
  stopifnot(!length(specmill::read_operations(swagger_file)$diagnostics))
  newer$paths[['/no-items']]$post$requestBody$content[[
    'application/json'
  ]]$schema$additionalProperties <- 'bad'
  jsonlite::write_json(newer, swagger_file, auto_unbox = TRUE)
  stopifnot(
    specmill::read_operations(swagger_file)$diagnostics[[1L]]$code ==
      'invalid_additional_properties'
  )
  # A normal initialization/plan must preserve the same evidence without writes.
  client <- file.path(root, 'client')
  initialization <- specmill::initialize_client(
    client,
    file,
    package = 'diagnosticclient',
    title = 'Diagnostic Client',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'test@example.org'
    ),
    license = 'MIT + file LICENSE',
    base_url = 'https://example.invalid'
  )
  service_path <- file.path(client, 'apis/checks.yml')
  service <- yaml::read_yaml(service_path, handlers = list(seq = function(x) x))
  service$selection$methods <- list('GET', 'POST')
  yaml::write_yaml(service, service_path)
  snapshot <- function() {
    tools::md5sum(list.files(
      client,
      recursive = TRUE,
      all.files = TRUE,
      full.names = TRUE
    ))
  }
  before <- snapshot()
  plan <- specmill::generate_client(
    client,
    config = 'specmill.yml',
    mode = 'plan'
  )
  stopifnot(
    identical(before, snapshot()),
    length(plan$operations) == 3L,
    length(plan$diagnostics) == length(expected),
    by_key(plan$excluded, 'DELETE /excluded')$classification ==
      'policy_exclusion'
  )
  for (key in names(expected)) {
    stopifnot(identical(
      by_key(plan$diagnostics, key)$classification,
      expected[[key]][[1L]]
    ))
  }
  proposal <- specmill::configure_client(
    client,
    file,
    package = 'diagnosticclient',
    mode = 'plan'
  )
  native <- Filter(
    function(x) identical(x$code, 'unsupported'),
    proposal$diagnostics
  )
  stopifnot(
    length(native) > 0L,
    all(vapply(
      native,
      function(x) nzchar(x$guidance) && nzchar(x$source_location),
      logical(1)
    ))
  )
  # Preserve invalid reference errors and correctly escape unusual route names.
  document$paths <- list(
    '/a~b/c' = list(post = operation('escaped', list('$ref' = '#/bad~escape')))
  )
  jsonlite::write_json(document, file, auto_unbox = TRUE)
  escaped <- specmill::read_operations(file)$diagnostics[[1L]]
  stopifnot(
    escaped$code == 'invalid_reference',
    startsWith(escaped$source_location, '#/paths/~1a~0b~1c/post')
  )
  cat(
    'Diagnostics: schema context, reference causes, policy exclusions, propagation and read-only plan passed.\n'
  )
}
if (sys.nframe() == 0L) {
  diagnostics_acceptance()
}
