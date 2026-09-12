schema_loading_acceptance <- function() {
  root <- tempfile('schema-loading-')
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  document <- list(
    openapi = '3.0.3',
    info = list(title = 'Loading API', version = '1'),
    servers = list(list(url = 'https://loading.invalid')),
    paths = list(
      '/items' = list(
        get = list(
          operationId = 'read_items',
          tags = list('items'),
          parameters = list(list(
            name = 'page',
            'in' = 'query',
            schema = list(type = 'integer', default = 2L)
          )),
          responses = list('200' = list(description = 'OK'))
        )
      )
    )
  )
  paths <- file.path(root, paste0('api.', c('json', 'yaml', 'yml')))
  jsonlite::write_json(document, paths[[1L]], auto_unbox = TRUE)
  for (path in paths[-1L]) {
    yaml::write_yaml(document, path)
  }
  original <- tools::md5sum(paths)
  # Provenance is the only difference between equivalent source formats.
  contract <- function(x) {
    if (!is.list(x)) {
      return(x)
    }
    if (!is.null(names(x))) {
      x <- x[setdiff(names(x), c('source', 'source_hash'))]
    }
    lapply(x, contract)
  }
  expected <- specmill::read_operations(paths[[1L]])
  stopifnot(length(expected$operations) == 1L, !length(expected$diagnostics))
  for (path in paths) {
    parsed <- specmill::read_operations(path)
    stopifnot(identical(contract(parsed), contract(expected)))
    context <- new.env(parent = baseenv())
    context$request <- function(...) list(...)
    eval(
      parse(
        text = specmill::render_operation(
          parsed$operations$read_items,
          list(helper = 'request')
        )
      ),
      context
    )
    stopifnot(identical(context$read_items()$query, list(page = 2L)))
    stopifnot(identical(
      specmill::operation_fixtures(parsed$operations),
      specmill::operation_fixtures(expected$operations)
    ))
    client <- file.path(root, paste0('client-', tools::file_ext(path)))
    proposal <- specmill::configure_client(client, path, package = 'loadclient')
    stopifnot(!dir.exists(client), length(proposal$operations) == 1L)
    specmill::initialize_client(
      client,
      path,
      package = 'loadclient',
      title = 'Schema Loading',
      author = list(
        given = 'Test',
        family = 'Maintainer',
        email = 'test@example.org'
      ),
      license = 'MIT + file LICENSE'
    )
    helper <- file.path(client, 'R/api_request.R')
    cat('\n# Client-owned helper annotation\n', file = helper, append = TRUE)
    protected <- c(
      helper,
      file.path(client, 'specmill.yml'),
      list.files(
        file.path(client, 'apis'),
        full.names = TRUE
      )
    )
    before <- tools::md5sum(protected)
    for (mode in c('plan', 'apply', 'check')) {
      plan <- specmill::generate_client(
        client,
        config = 'specmill.yml',
        mode = mode
      )
      stopifnot(length(plan$operations) == 1L)
    }
    stopifnot(identical(before, tools::md5sum(protected)))
    # Explicit YAML schema paths in existing configuration also work directly.
    service_path <- list.files(file.path(client, 'apis'), full.names = TRUE)[[
      1L
    ]]
    service <- yaml::read_yaml(
      service_path,
      handlers = list(seq = function(x) x)
    )
    copied <- file.path(client, basename(path))
    stopifnot(file.copy(path, copied))
    service$schemas$files <- list(basename(path))
    yaml::write_yaml(service, service_path)
    direct <- specmill::generate_client(
      client,
      config = 'specmill.yml',
      mode = 'plan'
    )
    stopifnot(length(direct$operations) == 1L)
  }
  catalogue <- specmill::configure_apis(root, review = FALSE)
  stopifnot(
    setequal(catalogue$schema, basename(paths)),
    length(unique(catalogue$hash)) == 1L,
    sum(catalogue$include) == 1L,
    !file.exists(file.path(root, 'specmill-apis.yml')),
    identical(original, tools::md5sum(paths))
  )
  specmill::configure_apis(root, review = FALSE, mode = 'apply')
  catalogue_hash <- tools::md5sum(file.path(root, 'specmill-apis.yml'))
  repeated <- specmill::configure_apis(root, review = FALSE)
  stopifnot(
    identical(catalogue$api, repeated$api),
    identical(
      catalogue_hash,
      tools::md5sum(file.path(root, 'specmill-apis.yml'))
    )
  )
  multi <- file.path(root, 'multi')
  dir.create(multi)
  stopifnot(all(file.copy(paths[-1L], multi)))
  specmill::initialize_client(
    multi,
    data.frame(
      schema = basename(paths[-1L]),
      api = c('one', 'two'),
      base_url = 'https://loading.invalid',
      include = TRUE
    ),
    package = 'multiload',
    title = 'Multiple YAML Schemas',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'test@example.org'
    ),
    license = 'MIT + file LICENSE'
  )
  multi_plan <- specmill::generate_client(
    multi,
    config = 'specmill.yml',
    mode = 'plan'
  )
  stopifnot(
    length(multi_plan$operations) == 2L,
    all(file.exists(file.path(multi, 'schema', c('one.yaml', 'two.yml'))))
  )
  old <- file.path(root, 'old')
  new <- file.path(root, 'new')
  dir.create(old)
  dir.create(new)
  for (extension in c('yaml', 'yml')) {
    path <- paste0('sample-', extension, '-prod.', extension)
    yaml::write_yaml(document, file.path(old, path))
    yaml::write_yaml(document, file.path(new, path))
  }
  stopifnot(!length(specmill::schema_diff(old, new, stage_priority = 'prod')))
  changed <- document
  changed$paths[['/items']]$get$parameters[[1L]]$schema$type <- 'string'
  yaml::write_yaml(changed, file.path(new, 'sample-yaml-prod.yaml'))
  drift <- specmill::schema_diff(old, new, stage_priority = 'prod')
  stopifnot(length(drift) == 1L, nrow(drift[[1L]]$modified) == 1L)
  # Unsupported contracts retain the same operation key and source location.
  document$paths[['/items']]$get$parameters[[1L]]$schema <- list(
    type = 'array',
    items = list(type = 'object')
  )
  jsonlite::write_json(document, paths[[1L]], auto_unbox = TRUE)
  for (path in paths[-1L]) {
    yaml::write_yaml(document, path)
  }
  expected <- specmill::read_operations(paths[[1L]])
  stopifnot(length(expected$diagnostics) == 1L)
  for (path in paths[-1L]) {
    stopifnot(identical(
      contract(specmill::read_operations(path)),
      contract(expected)
    ))
  }
  cat(
    'Schema loading: JSON/YAML/YML metadata, diagnostics, fixtures, catalogue identity, initialization, configuration and generation passed offline.\n'
  )
}
if (sys.nframe() == 0L) {
  schema_loading_acceptance()
}
