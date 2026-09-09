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
  # Explicit renaming is a paired replacement; an edited original blocks it.
  put(c(service, 'names:', '  GET /items: renamed_items'))
  old_path <- file.path(root, 'R/list_items.R')
  old_text <- readLines(old_path)
  writeLines(c(old_text, '# local edit'), old_path)
  fails(
    apipak::generate_client(root, config = 'apipak.yml', mode = 'apply'),
    'Protected original'
  )
  stopifnot(!file.exists(file.path(root, 'R/renamed_items.R')))
  writeLines(old_text, old_path)
  apipak::generate_client(root, config = 'apipak.yml', mode = 'apply')
  stopifnot(
    !file.exists(old_path),
    file.exists(file.path(root, 'R/renamed_items.R'))
  )
  apipak::generate_client(root, config = 'apipak.yml', mode = 'check')
  put(c(service, 'names:', '  GET /items: list_items'))
  apipak::generate_client(root, config = 'apipak.yml', mode = 'apply')
  put(service)
  apipak::generate_client(root, config = 'apipak.yml', mode = 'apply')
  inspected <- apipak::inspect_client(root)
  stopifnot(
    inspected$coverage$catalogue$total == 3L,
    inspected$coverage$catalogue$implemented == 3L,
    inspected$coverage$catalogue$contracts == 0L,
    !length(inspected$diagnostics),
    identical(applied, hashes())
  )
  writeLines(
    c("#' @export", 'manual_extra <- function() 1'),
    file.path(root, 'R/manual_extra.R')
  )
  cat(
    '\nexport(manual_extra)\n',
    file = file.path(root, 'NAMESPACE'),
    append = TRUE
  )
  inspected <- apipak::inspect_client(root)
  stopifnot(
    'manual_extra' %in% names(inspected$manual_exports),
    inspected$coverage$catalogue$total == 3L
  )
  fixture_path <- file.path(root, 'tests/testthat/fixtures/fixed.rds')
  dir.create(dirname(fixture_path), recursive = TRUE, showWarnings = FALSE)
  fixed <- list(
    list_items = list(
      inputs = list(page = 2L),
      calls = list(list(
        helper = 'catalogue_request',
        arguments = list(
          method = 'GET',
          path = '/items',
          path_params = list(),
          query = list(page = 2L),
          body = NULL
        ),
        response = tibble::tibble(count = 0L)
      )),
      result = tibble::tibble(count = 0L)
    )
  )
  saveRDS(fixed, fixture_path)
  put(c(service, 'contracts_file: tests/testthat/fixtures/fixed.rds'))
  loaded <- apipak::load_project(root)
  stopifnot(
    identical(loaded$services$catalogue$contracts, fixed),
    normalizePath(fixture_path, winslash = '/') %in% loaded$inputs
  )
  apipak::generate_client(root, config = 'apipak.yml', mode = 'plan')
  fixed$list_items$result <- function() NULL
  saveRDS(fixed, fixture_path)
  fails(apipak::load_project(root), 'only R data')
  put(service)
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
  callbacks <- new.env(parent = baseenv())
  callbacks$mutate <- function(operation) {
    writeLines(
      'added_during_generation <- function() NULL',
      file.path(root, 'R/added.R')
    )
    operation
  }
  put(c(service, 'prepare: mutate'))
  fails(
    apipak::generate_client(
      root,
      config = 'apipak.yml',
      callbacks = callbacks,
      mode = 'apply'
    ),
    'generation input files changed'
  )
  unlink(file.path(root, 'R/added.R'))
  put(service)
  cat(
    'Configuration: YAML selection, original paths, aliases, strict validation, outside-root generation, read-only plans and second apply passed.\n'
  )
}
if (sys.nframe() == 0L) {
  configuration_acceptance()
}
