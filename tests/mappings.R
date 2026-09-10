mappings_acceptance <- function() {
  source <- tempfile(fileext = '.R')
  writeLines(
    c(
      'base::identity(NULL)',
      '(function() stop("must not run"))()',
      'mapped <- function(x) x'
    ),
    source
  )
  definitions <- getFromNamespace('tg_find_function_defs_in_file', 'specmill')
  stopifnot(identical(names(definitions(source)), 'mapped'))
  writeLines('broken <- function(', source)
  stopifnot(inherits(tryCatch(definitions(source), error = identity), 'error'))
  root <- tempfile('mapped-client-')
  dir.create(root)
  fixture <- system.file('catalogue', package = 'specmill', mustWork = TRUE)
  stopifnot(all(file.copy(
    list.files(fixture, full.names = TRUE),
    root,
    recursive = TRUE
  )))
  writeLines(
    c('config_version: 1', 'services: [service.yml]'),
    file.path(root, 'specmill.yml')
  )
  service <- c(
    'id: mapped',
    'schemas: {files: [schema.json]}',
    'helper: catalogue_request',
    'selection: {methods: [GET], exclude: ["^/items$"]}',
    'hooks:',
    '  get_item: {pre_request: [normalize_input], post_response: [extract_output]}',
    'operations:',
    '  GET /items/{item_id}:',
    '    parameters:',
    '      path item_id: {name: identifier}',
    '      query language: {default: fr}',
    '    extra_parameters:',
    '      enabled: {type: logical, default: false}',
    '      mode: {type: character, default: [wide, raw]}',
    '    parameter_order: [identifier, mode, language, enabled]',
    '    request:',
    '      arguments:',
    '        route: {value: items}',
    '        id: {from: [params, identifier]}',
    '        language: {from: [params, language]}',
    '        enabled: {from: [params, enabled]}',
    '        amount: {value: 0.0}',
    '        payload: {value: [null]}',
    '    docs:',
    '      title: Mapped item',
    '      lifecycle: stable',
    '      examples: [{identifier: sample}]'
  )
  put <- function(lines) writeLines(lines, file.path(root, 'service.yml'))
  put(service)
  project <- specmill::load_project(root)
  selected <- project$services$mapped
  operation <- specmill::read_operations(
    selected$files,
    selected$policy
  )$operations[[1L]]
  configured <- getFromNamespace('configure_operation', 'specmill')(
    operation,
    selected
  )
  env <- new.env(parent = baseenv())
  calls <- list()
  order <- character()
  skip <- FALSE
  env$run_hook <- function(name, stage, data) {
    order <<- c(order, stage)
    if (stage == 'pre_request') {
      data$params <- list(
        identifier = trimws(data$params$identifier),
        language = NULL
      )
      data$skip_request <- skip
      data$result <- 'skipped'
      return(data)
    }
    stopifnot(
      identical(data$params$enabled, FALSE),
      is.null(data$params$language)
    )
    data$result
  }
  env$catalogue_request <- function(...) {
    calls[[length(calls) + 1L]] <<- list(...)
    order <<- c(order, 'request')
    'complete'
  }
  render <- function(spec = configured$spec) {
    eval(
      parse(text = specmill::render_operation(configured$operation, spec)),
      env
    )
    env$get_item
  }
  fn <- render()
  stopifnot(identical(
    formals(fn),
    formals(function(
      identifier,
      mode = c('wide', 'raw'),
      language = 'fr',
      enabled = FALSE
    ) {
      NULL
    })
  ))
  stopifnot(identical(fn(' sample '), 'complete'))
  stopifnot(identical(
    calls,
    list(list(
      route = 'items',
      id = 'sample',
      language = NULL,
      enabled = FALSE,
      amount = 0,
      payload = list(NULL)
    ))
  ))
  stopifnot(identical(order, c('pre_request', 'request', 'post_response')))
  calls <- list()
  order <- character()
  skip <- TRUE
  stopifnot(
    identical(fn('sample'), 'skipped'),
    !length(calls),
    identical(order, 'pre_request')
  )
  spec <- configured$spec
  spec$post_on_skip <- TRUE
  spec$post_state <- 'hook_state'
  order <- character()
  fn <- render(spec)
  # The post hook receives the complete pre-hook state on the configured path.
  env$run_hook <- function(name, stage, data) {
    order <<- c(order, stage)
    if (stage == 'pre_request') {
      return(list(
        params = data$params,
        skip_request = TRUE,
        result = 'skipped',
        sentinel = 42L
      ))
    }
    stopifnot(identical(data$sentinel, 42L))
    data$result
  }
  stopifnot(
    identical(fn('sample'), 'skipped'),
    !length(calls),
    identical(order, c('pre_request', 'post_response'))
  )
  fails <- function(lines, pattern) {
    put(lines)
    error <- tryCatch(
      specmill::generate_client(root, config = 'specmill.yml', mode = 'plan'),
      error = identity
    )
    stopifnot(inherits(error, 'error'), grepl(pattern, conditionMessage(error)))
  }
  fails(
    sub('path item_id:', 'path missing:', service, fixed = TRUE),
    'Unknown parameter'
  )
  fails(
    sub('name: identifier', 'name: language', service, fixed = TRUE),
    'colliding'
  )
  fails(
    sub('[params, identifier]', '[params, missing]', service, fixed = TRUE),
    'missing public parameter'
  )
  fails(
    sub('[params, identifier]', '[global, identifier]', service, fixed = TRUE),
    'start with'
  )
  fails(c(service, '      tags: {eval: malicious}'), 'Unsafe documentation tag')
  fails(
    sub(
      'required: true',
      'required: false',
      c(service, '    post_on_skip: invalid'),
      fixed = TRUE
    ),
    'true or false'
  )
  mapped <- c(
    'id: mapped',
    'schemas: {files: [schema.json]}',
    'helper: catalogue_request',
    'selection: {methods: [GET], exclude: ["^/items$"]}',
    'defaults:',
    '  request: {arguments: {amount: {value: 10.0}}}',
    'operations:',
    '  GET /items/{item_id}:',
    '    inputs:',
    '      query: {type: character, required: true}',
    '      limit: {type: numeric, default: 0.0}',
    '    request:',
    '      arguments:',
    '        amount: {from: [params, limit]}',
    '        body: {object: {search: {from: [params, query]}, nullable: {value: null}}}',
    '        options: {vector: {limit: {from: [params, limit]}}}',
    '        rows: {array: [{object: {query: {from: [params, query]}}}, {value: null}]}',
    '        compact: {compact_object: {zero: {value: 0.0}, retained: {value: false}, omitted: {value: null}}}',
    '        empty: {compact_object: {omitted: {value: null}}}',
    '        batch: {callback: batch_default}'
  )
  put(mapped)
  callbacks <- new.env(parent = emptyenv())
  callbacks$batch_default <- function(operation) {
    quote(as.numeric(Sys.getenv('APIPAK_TEST_BATCH', '1000')))
  }
  previous_batch <- Sys.getenv('APIPAK_TEST_BATCH', unset = NA_character_)
  Sys.unsetenv('APIPAK_TEST_BATCH')
  on.exit(
    if (is.na(previous_batch)) {
      Sys.unsetenv('APIPAK_TEST_BATCH')
    } else {
      Sys.setenv(APIPAK_TEST_BATCH = previous_batch)
    },
    add = TRUE
  )
  project <- specmill::load_project(root, callbacks = callbacks)
  selected <- project$services$mapped
  operation <- specmill::read_operations(
    selected$files,
    selected$policy
  )$operations[[1L]]
  configured <- getFromNamespace('configure_operation', 'specmill')(
    operation,
    selected
  )
  eval(
    parse(
      text = specmill::render_operation(configured$operation, configured$spec)
    ),
    env
  )
  env$catalogue_request <- function(...) list(...)
  stopifnot(identical(
    formals(env$get_item),
    formals(function(query, limit = 0) NULL)
  ))
  stopifnot(identical(
    env$get_item('a/b'),
    list(
      amount = 0,
      body = list(search = 'a/b', nullable = NULL),
      options = c(limit = 0),
      rows = list(list(query = 'a/b'), NULL),
      compact = list(zero = 0, retained = FALSE),
      empty = list(),
      batch = 1000
    )
  ))
  stopifnot(
    length(configured$operation$schema_parameters) == 2L,
    is.null(configured$operation$body)
  )
  stopifnot(inherits(tryCatch(env$get_item(), error = identity), 'error'))
  put(sub('rows: .*', 'rows: {array: {query: {value: 1}}}', mapped))
  error <- tryCatch(
    specmill::load_project(root, callbacks = callbacks),
    error = identity
  )
  stopifnot(
    inherits(error, 'error'),
    grepl('sequence of bindings', conditionMessage(error))
  )
  put(mapped)
  stopifnot(identical(
    env$get_item(NULL)$body,
    list(search = NULL, nullable = NULL)
  ))
  missing_policy <- sub(
    'query: {type: character, required: true}',
    'query: {type: character, required: true, missing_as_null: true}',
    mapped,
    fixed = TRUE
  )
  stopifnot(!identical(missing_policy, mapped))
  put(missing_policy)
  missing_service <- specmill::load_project(
    root,
    callbacks = callbacks
  )$services[[1L]]
  missing_configured <- getFromNamespace('configure_operation', 'specmill')(
    operation,
    missing_service
  )
  eval(
    parse(
      text = specmill::render_operation(
        missing_configured$operation,
        missing_configured$spec
      )
    ),
    env
  )
  stopifnot(identical(env$get_item()$body, env$get_item(NULL)$body))
  put(mapped)
  configured$spec$documentation <- TRUE
  configured$spec$docs <- list(
    examples = list(list(query = list('first', 'second')))
  )
  documented <- specmill::render_operation(configured$operation, configured$spec)
  example <- sub(
    "^#' ",
    '',
    grep("^#' get_item\\(", strsplit(documented, '\n')[[1L]], value = TRUE)
  )
  stopifnot(identical(
    eval(parse(text = example), env)$body$search,
    c('first', 'second')
  ))
  error <- tryCatch(specmill::load_project(root), error = identity)
  stopifnot(
    inherits(error, 'error'),
    grepl('Unresolved callback', conditionMessage(error))
  )
  cat(
    'Mappings: typed defaults, aliases, request bindings, hook order, skip/state semantics, and invalid configuration passed.\n'
  )
}
if (sys.nframe() == 0L) {
  mappings_acceptance()
}
