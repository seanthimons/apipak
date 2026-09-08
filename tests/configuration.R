configuration_acceptance <- function() {
  root <- tempfile('yaml-client-')
  dir.create(root)
  fixture <- system.file('catalogue', package = 'apipak', mustWork = TRUE)
  stopifnot(all(file.copy(
    list.files(fixture, full.names = TRUE),
    root,
    recursive = TRUE
  )))
  writeLines(
    c('config_version: 1', 'services: [catalogue.yml]'),
    file.path(root, 'apipak.yml')
  )
  service <- c(
    'id: catalogue',
    'schemas:',
    '  files: [schema.json]',
    'helper: catalogue_request',
    'selection:',
    '  methods: [GET, POST]',
    '  exclude: ["^/refresh$", "^/items/not-a-route$"]'
  )
  put <- function(lines) writeLines(lines, file.path(root, 'catalogue.yml'))
  put(service)
  previous <- setwd(tempdir())
  on.exit(setwd(previous), add = TRUE)
  hashes <- function() {
    tools::md5sum(list.files(
      root,
      recursive = TRUE,
      all.files = TRUE,
      full.names = TRUE
    ))
  }
  original <- hashes()
  plan <- apipak::generate_client(root, config = 'apipak.yml', mode = 'plan')
  stopifnot(
    length(plan$operations) == 3L,
    length(plan$inventory) == 4L,
    sum(vapply(
      plan$inventory,
      function(x) x$status == 'excluded',
      logical(1)
    )) ==
      1L,
    identical(original, hashes()),
    all(vapply(
      plan$operations,
      function(x) startsWith(x$id, 'catalogue '),
      logical(1)
    ))
  )
  fails <- function(expr, pattern = NULL) {
    e <- tryCatch(
      {
        force(expr)
        NULL
      },
      error = identity
    )
    stopifnot(inherits(e, 'error'))
    if (!is.null(pattern)) stopifnot(grepl(pattern, conditionMessage(e)))
  }
  fails(apipak::generate_client(root, config = 'apipak.yml'), 'stale')
  apipak::generate_client(root, config = 'apipak.yml', mode = 'apply')
  applied <- hashes()
  apipak::generate_client(root, config = 'apipak.yml', mode = 'check')
  apipak::generate_client(root, config = 'apipak.yml', mode = 'apply')
  stopifnot(identical(applied, hashes()))
  fails(
    apipak::generate_client(root, list(), config = 'apipak.yml'),
    'exactly one'
  )
  invalid <- list(
    c(service, 'unknown: true'),
    sub('GET, POST', 'GET, INVALID', service, fixed = TRUE),
    sub('files: [schema.json]', 'files: schema.json', service, fixed = TRUE),
    sub(
      'files: [schema.json]',
      'files: [../schema.json]',
      service,
      fixed = TRUE
    ),
    c(service, 'helper: other_helper'),
    c(service, 'prepare: missing_callback'),
    c(service, 'names:', '  "GET /absent": missing'),
    sub('^/refresh$', '[', service, fixed = TRUE),
    sub(
      'files: [schema.json]',
      'patterns: [absent-*.json]',
      service,
      fixed = TRUE
    )
  )
  for (lines in invalid) {
    put(lines)
    fails(apipak::generate_client(root, config = 'apipak.yml', mode = 'plan'))
  }
  writeLines(
    'strict_request <- function(endpoint) NULL',
    file.path(root, 'R/strict.R')
  )
  put(sub(
    'helper: catalogue_request',
    'helper: strict_request',
    service,
    fixed = TRUE
  ))
  fails(
    apipak::generate_client(root, config = 'apipak.yml', mode = 'plan'),
    'Missing required helper arguments'
  )
  old <- options(yaml.eval.expr = TRUE)
  on.exit(options(old), add = TRUE)
  marker <- tempfile('yaml-execution-')
  put(c(
    service,
    paste0('prepare: !expr writeLines("executed", ', deparse(marker), ')')
  ))
  fails(apipak::load_project(root))
  stopifnot(!file.exists(marker))
  # Explicit map keys override a merged default regardless of key order.
  put(c(
    'id: catalogue',
    'schemas: {files: [schema.json]}',
    'helper: catalogue_request',
    'selection: {<<: &defaults {methods: [POST]}, methods: [GET]}'
  ))
  loaded <- apipak::load_project(root)
  stopifnot(identical(loaded$services$catalogue$policy$methods, 'GET'))
  put(service)
  cat(
    'Configuration: YAML selection, original paths, aliases, strict validation, outside-root generation, read-only plans and second apply passed.\n'
  )
}
if (sys.nframe() == 0L) {
  configuration_acceptance()
}
