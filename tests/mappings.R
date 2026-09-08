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
  definitions <- getFromNamespace('tg_find_function_defs_in_file', 'apipak')
  stopifnot(identical(names(definitions(source)), 'mapped'))
  writeLines('broken <- function(', source)
  stopifnot(inherits(tryCatch(definitions(source), error = identity), 'error'))
  root <- tempfile('mapped-client-')
  dir.create(root)
  fixture <- system.file('catalogue', package = 'apipak', mustWork = TRUE)
  stopifnot(all(file.copy(
    list.files(fixture, full.names = TRUE),
    root,
    recursive = TRUE
  )))
  writeLines(
    c('config_version: 1', 'services: [service.yml]'),
    file.path(root, 'apipak.yml')
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
  project <- apipak::load_project(root)
  selected <- project$services$mapped
  operation <- apipak::read_operations(
    selected$files,
    selected$policy
  )$operations[[1L]]
  configured <- getFromNamespace('configure_operation', 'apipak')(
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
      parse(text = apipak::render_operation(configured$operation, spec)),
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
      apipak::generate_client(root, config = 'apipak.yml', mode = 'plan'),
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
  cat(
    'Mappings: typed defaults, aliases, request bindings, hook order, skip/state semantics, and invalid configuration passed.\n'
  )
}
if (sys.nframe() == 0L) {
  mappings_acceptance()
}
