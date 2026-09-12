mapped_schema_acceptance <- function() {
  root <- tempfile('mapped-schema-')
  dir.create(root)
  dir.create(file.path(root, 'R'))
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  writeLines(
    'request_helper <- function(body) body',
    file.path(root, 'R/helper.R')
  )
  writeLines(
    c('config_version: 1', 'services: [service.yml]'),
    file.path(root, 'specmill.yml')
  )
  writeLines(
    c(
      'id: records',
      'schemas: {files: [schema.json]}',
      'helper: request_helper',
      'operations:',
      '  POST /records:',
      '    inputs: {payload: {type: object, required: true}}',
      '    request: {arguments: {body: {from: [params, payload]}}}'
    ),
    file.path(root, 'service.yml')
  )
  document <- list(
    openapi = '3.0.3',
    paths = list(
      '/records' = list(
        post = list(
          operationId = 'submit_records',
          requestBody = list(
            required = TRUE,
            content = list(
              'application/json' = list(
                schema = list(type = 'object', additionalProperties = TRUE)
              )
            )
          ),
          responses = list('200' = list(description = 'ok'))
        )
      )
    )
  )
  file <- file.path(root, 'schema.json')
  put <- function(schema) {
    document$paths[['/records']]$post$requestBody$content[[
      'application/json'
    ]]$schema <- schema
    jsonlite::write_json(document, file, auto_unbox = TRUE)
  }
  for (schema in list(
    list(type = 'object', additionalProperties = TRUE),
    stats::setNames(list(), character()),
    list(oneOf = list(list(type = 'string'), list(type = 'number'))),
    list(
      oneOf = list(list(type = 'string', not = list(enum = list('blocked'))))
    )
  )) {
    put(schema)
    native <- specmill::read_operations(file)
    unsupported <- !is.null(schema$oneOf[[1L]]$not)
    stopifnot(
      length(native$operations) == as.integer(!unsupported),
      length(native$unsupported_operations) == as.integer(unsupported),
      length(native$diagnostics) == as.integer(unsupported),
      native$inventory[[1L]]$status ==
        if (unsupported) 'unsupported' else 'selected'
    )
    result <- specmill::generate_client(
      root,
      config = 'specmill.yml',
      mode = 'apply'
    )
    stopifnot(
      length(result$operations) == 1L,
      !length(result$diagnostics)
    )
    if (unsupported) {
      stopifnot(
        length(result$mapping_diagnostics) == 1L,
        result$mapping_diagnostics[[1L]]$classification == 'capability_gap',
        nzchar(result$mapping_diagnostics[[1L]]$source_location),
        result$inventory[[1L]]$classification == 'capability_gap',
        result$inventory[[1L]]$status == 'client-mapped',
        nzchar(result$inventory[[1L]]$reason)
      )
    }
    if (!unsupported) {
      stopifnot(!length(result$mapping_diagnostics))
    }
    env <- new.env(parent = baseenv())
    sys.source(file.path(root, 'R/helper.R'), env)
    sys.source(file.path(root, 'R/submit_records.R'), env)
    payload <- list(arbitrary = list(FALSE, 0, NULL))
    stopifnot(identical(env$submit_records(payload), payload))
    specmill::generate_client(root, config = 'specmill.yml', mode = 'check')
  }
  for (schema in list(
    list(type = 'dict'),
    list(type = 'object', properties = list()),
    list('$ref' = '#/missing'),
    list('$ref' = 'https://example.test/schema.json'),
    list(oneOf = list())
  )) {
    put(schema)
    parsed <- specmill::read_operations(file)
    stopifnot(
      !length(parsed$unsupported_operations),
      length(parsed$diagnostics) == 1L
    )
    error <- tryCatch(
      specmill::generate_client(root, config = 'specmill.yml', mode = 'apply'),
      error = identity
    )
    stopifnot(
      inherits(error, 'error'),
      grepl('Unsupported selected', conditionMessage(error))
    )
  }
  resolve <- getFromNamespace('local_ref', 'specmill')
  references <- list('~1' = list(type = 'string'), '/' = list(type = 'number'))
  stopifnot(identical(
    resolve(list('$ref' = '#/~01'), references),
    list(type = 'string')
  ))
  error <- tryCatch(
    resolve(list('$ref' = '#/~2'), references),
    error = identity
  )
  stopifnot(
    inherits(error, 'error'),
    grepl('Invalid reference escape', conditionMessage(error))
  )
  cat(
    'Mapped schemas: explicit facade mappings retain native diagnostics; malformed metadata and references remain blocking.\n'
  )
}
if (sys.nframe() == 0L) {
  mapped_schema_acceptance()
}
