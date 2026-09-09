source_layout_acceptance <- function() {
  root <- tempfile('source-layout-')
  dir.create(root)
  dir.create(file.path(root, 'R'))
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  metadata <- file.path(root, 'metadata.R')
  writeLines(
    c(
      'text <- "',
      'fake <- function() {}',
      '"',
      "#' First function",
      "#' @export",
      'first <- function(',
      ' x',
      ') x',
      "#' Second function",
      "#' @export",
      'second <-',
      ' function() 2'
    ),
    metadata
  )
  definitions <- getFromNamespace('tg_find_function_defs_in_file', 'apipak')(
    metadata,
    documentation = TRUE
  )
  stopifnot(
    identical(names(definitions), c('first', 'second')),
    identical(
      definitions$first$documentation,
      c("#' First function", "#' @export")
    ),
    identical(
      definitions$second$documentation,
      c("#' Second function", "#' @export")
    )
  )
  file.copy(
    system.file('catalogue/schema.json', package = 'apipak'),
    file.path(root, 'schema.json')
  )
  writeLines(
    'request_helper <- function(...) list(...)',
    file.path(root, 'R/helper.R')
  )
  writeLines(
    c('config_version: 1', 'services: [service.yml]'),
    file.path(root, 'apipak.yml')
  )
  service <- c(
    'id: catalogue',
    'schemas: {files: [schema.json]}',
    'helper: request_helper',
    'defaults: {file: R/generated.R}'
  )
  put <- function(lines) writeLines(lines, file.path(root, 'service.yml'))
  run <- function(mode) {
    apipak::generate_client(root, config = 'apipak.yml', mode = mode)
  }
  put(service)
  result <- run('apply')
  path <- file.path(root, 'R/generated.R')
  stopifnot(
    length(result$operations) == 4L,
    length(getFromNamespace('tg_find_function_defs_in_file', 'apipak')(path)) ==
      4L
  )
  run('check')
  stopifnot(all(vapply(
    run('apply')$files,
    function(x) x$action == 'unchanged',
    logical(1)
  )))
  original <- readLines(path)
  # Exact reviewed hashes adopt legacy output without weakening mixed-file checks.
  unlink(file.path(root, '.apipak'), recursive = TRUE)
  hashes <- list(
    'R/generated.R' = getFromNamespace('output_hash', 'apipak')(path)
  )
  apipak::generate_client(
    root,
    config = 'apipak.yml',
    mode = 'apply',
    adopt = hashes
  )
  manifest <- file.path(root, '.apipak/manifest.json')
  stopifnot(file.exists(manifest))
  before_manifest <- tools::md5sum(manifest)
  run('apply')
  stopifnot(identical(before_manifest, tools::md5sum(manifest)))
  writeLines(c(original, '# Changed since review'), path)
  error <- tryCatch(
    apipak::generate_client(
      root,
      config = 'apipak.yml',
      mode = 'apply',
      adopt = hashes
    ),
    error = identity
  )
  stopifnot(
    inherits(error, 'error'),
    grepl('adoption hash differs', conditionMessage(error))
  )
  writeLines(c(original, 'local_value <- 10'), path)
  error <- tryCatch(run('apply'), error = identity)
  stopifnot(
    inherits(error, 'error'),
    grepl('Mixed file', conditionMessage(error))
  )
  unlink(path)
  manual <- file.path(root, 'R/manual.R')
  writeLines(
    c(
      '# lifecycle::badge("stable")',
      "get_item <- function(item_id, language = 'en') list(id = item_id, language = language)",
      'manual_value <- 10'
    ),
    manual
  )
  original_hash <- tools::md5sum(manual)
  policy <- c(
    service,
    'operations:',
    '  GET /items/{item_id}:',
    '    file: R/manual.R',
    '    implementation: existing',
    '    inputs:',
    '      item_id: {required: true}',
    "      language: {default: en}",
    '    request: {arguments: {id: {from: [params, item_id]}}}'
  )
  put(policy)
  result <- run('apply')
  stopifnot(
    identical(result$retained_sources, 'R/manual.R'),
    identical(original_hash, tools::md5sum(manual))
  )
  run('check')
  put(sub('default: en', 'default: fr', policy, fixed = TRUE))
  error <- tryCatch(run('apply'), error = identity)
  stopifnot(
    inherits(error, 'error'),
    grepl('public contract differs', conditionMessage(error))
  )
  unlink(path)
  put(c(policy, '  POST /items:', '    file: R/manual.R'))
  error <- tryCatch(run('apply'), error = identity)
  stopifnot(
    inherits(error, 'error'),
    grepl('retained implementation', conditionMessage(error)),
    identical(original_hash, tools::md5sum(manual))
  )
  put(c(policy, 'names:', '  GET /items/{item_id}: get_item'))
  schema <- jsonlite::read_json(file.path(root, 'schema.json'))
  schema$paths[['/items/{item_id}']]$get$requestBody <- list(
    content = list(
      'application/json' = list(schema = list(type = 'dict'))
    )
  )
  jsonlite::write_json(
    schema,
    file.path(root, 'schema.json'),
    auto_unbox = TRUE
  )
  result <- run('apply')
  stopifnot(
    length(result$retained_diagnostics) == 1L,
    grepl(
      'Invalid input schema type',
      result$retained_diagnostics[[1L]]$reason
    ),
    identical(original_hash, tools::md5sum(manual))
  )
  cat(
    'Source layout: grouped generated operations, unchanged retained mixed files, exact public formals and conflict protection passed.\n'
  )
}
if (sys.nframe() == 0L) {
  source_layout_acceptance()
}
