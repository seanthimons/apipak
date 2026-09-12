local_references_acceptance <- function() {
  root <- tempfile('local-references-')
  dir.create(root)
  dir.create(file.path(root, 'operations'))
  dir.create(file.path(root, 'components'))
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  write <- function(value, path) {
    jsonlite::write_json(value, path, auto_unbox = TRUE, pretty = TRUE)
  }
  write(
    list(
      Page = list(
        name = 'page',
        'in' = 'query',
        schema = list('$ref' = 'schema.json#/Page')
      )
    ),
    file.path(root, 'components', 'parameters.json')
  )
  write(
    list(Page = list(type = 'integer', default = 7L)),
    file.path(root, 'components', 'schema.json')
  )
  write(list(Node = list(type = 'object')), file.path(root, 'base.json'))
  write(list(list(type = 'string')), file.path(root, 'array.json'))
  writeLines('{', file.path(root, 'malformed.json'))
  write(
    list(
      operationId = 'list_items',
      parameters = list(list('$ref' = '../components/parameters.json#/Page')),
      responses = list('200' = list(description = 'OK'))
    ),
    file.path(root, 'operations', 'list.json')
  )
  write(
    list(
      parameters = list(),
      get = list('$ref' = 'operations/list.json')
    ),
    file.path(root, 'path-item.json')
  )
  write(list('$ref' = 'cycle-b.json'), file.path(root, 'cycle-a.json'))
  write(list('$ref' = 'cycle-a.json'), file.path(root, 'cycle-b.json'))
  schema <- file.path(root, 'openapi.json')
  write(
    list(
      openapi = '3.0.3',
      info = list(title = 'Local references', version = '1'),
      servers = list(list(url = 'https://references.invalid')),
      paths = list(
        '/items' = list('$ref' = 'path-item.json'),
        '/internal' = list('$ref' = '#/components/pathItems/InternalItem'),
        '/missing' = list(get = list('$ref' = 'missing-operation.json')),
        '/remote' = list(
          get = list('$ref' = 'https://example.invalid/operation.json')
        ),
        '/malformed' = list(get = list('$ref' = 'malformed.json')),
        '/cycle' = list(get = list('$ref' = 'cycle-a.json'))
      ),
      components = list(
        sample = list(
          '$ref' = 'base.json#/Node',
          allOf = list(list('$ref' = 'components/schema.json#/Page'))
        ),
        array_item = list('$ref' = 'array.json#/0'),
        pathItems = list(
          InternalItem = list(
            get = list('$ref' = '#/components/x-operations/InternalOperation')
          )
        ),
        'x-operations' = list(
          InternalOperation = list(
            operationId = 'internal_items',
            responses = list('200' = list(description = 'OK'))
          )
        )
      )
    ),
    schema
  )
  document <- getFromNamespace('read_schema_document', 'specmill')(schema)
  dependencies <- attr(document, 'specmill_reference_dependencies')
  stopifnot(
    length(dependencies) == 10L,
    all(
      normalizePath(
        c(
          schema,
          file.path(root, 'path-item.json'),
          file.path(root, 'operations', 'list.json'),
          file.path(root, 'components', 'parameters.json'),
          file.path(root, 'components', 'schema.json')
        ),
        winslash = '/'
      ) %in%
        names(dependencies)
    )
  )
  stopifnot(
    identical(document$components$sample$allOf[[1L]]$type, 'integer'),
    identical(document$components$array_item$type, 'string')
  )
  parsed <- specmill::read_operations(schema)
  by_key <- function(records, key) {
    found <- Filter(function(x) identical(x$key, key), records)
    stopifnot(length(found) == 1L)
    found[[1L]]
  }
  operation <- by_key(parsed$operations, 'GET /items')
  inputs <- specmill::operation_fixtures(list(operation))[[1L]]
  stopifnot(
    identical(operation$operationId, 'list_items'),
    identical(operation$parameters[[1L]]$schema$type, 'integer'),
    identical(inputs$page, 7L)
  )
  stopifnot(identical(
    by_key(parsed$operations, 'GET /internal')$operationId,
    'internal_items'
  ))
  expected <- c(
    'GET /missing' = 'unresolved_reference',
    'GET /remote' = 'external_reference',
    'GET /malformed' = 'invalid_reference',
    'GET /cycle' = 'recursive_reference'
  )
  for (key in names(expected)) {
    diagnostic <- by_key(parsed$diagnostics, key)
    stopifnot(
      identical(diagnostic$classification, 'capability_gap'),
      identical(diagnostic$code, expected[[key]]),
      nzchar(diagnostic$reason)
    )
  }
  tracking <- tempfile('local-reference-inputs-')
  on.exit(unlink(tracking, recursive = TRUE), add = TRUE)
  specmill::initialize_client(
    tracking,
    schema,
    package = 'localreferenceinputs',
    title = 'Local reference inputs',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'test@example.org'
    ),
    license = 'MIT + file LICENSE'
  )
  source_files <- list.files(root, recursive = TRUE, full.names = TRUE)
  root_name <- paste0(normalizePath(root, winslash = '/'), '/')
  for (source in source_files) {
    relative <- substring(
      normalizePath(source, winslash = '/'),
      nchar(root_name) + 1L
    )
    destination <- file.path(tracking, 'schema', relative)
    dir.create(dirname(destination), recursive = TRUE, showWarnings = FALSE)
    stopifnot(file.copy(source, destination, overwrite = TRUE))
  }
  dependency <- normalizePath(
    file.path(tracking, 'schema', 'components', 'schema.json'),
    winslash = '/'
  )
  first <- specmill::generate_client(
    tracking,
    config = 'specmill.yml',
    mode = 'plan'
  )
  stopifnot(dependency %in% names(first$manifest$inputs))
  write(list(Page = list(type = 'integer', default = 8L)), dependency)
  second <- specmill::generate_client(
    tracking,
    config = 'specmill.yml',
    mode = 'plan'
  )
  stopifnot(
    !identical(
      first$manifest$inputs[[dependency]],
      second$manifest$inputs[[dependency]]
    )
  )
  client <- tempfile('local-reference-client-')
  on.exit(unlink(client, recursive = TRUE), add = TRUE)
  specmill::initialize_client(
    client,
    schema,
    package = 'localreferences',
    title = 'Local references',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'test@example.org'
    ),
    license = 'MIT + file LICENSE'
  )
  unlink(root, recursive = TRUE)
  generated <- specmill::generate_client(
    client,
    config = 'specmill.yml',
    mode = 'plan'
  )
  stopifnot(
    length(generated$operations) == 2L
  )
  cat(
    'Local references: relative pathItem and operation refs, nested files, cycles, missing files and remote diagnostics passed offline.\n'
  )
}

if (sys.nframe() == 0L) {
  local_references_acceptance()
}
