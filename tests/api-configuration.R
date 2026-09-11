api_configuration_acceptance <- function() {
  root <- tempfile('api-configuration-')
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  schema <- list(
    openapi = '3.0.3',
    info = list(title = 'API', version = '1'),
    paths = list(
      '/items' = list(
        get = list(
          operationId = 'read',
          tags = list('read'),
          responses = list('200' = list(description = 'OK'))
        ),
        post = list(
          operationId = 'write',
          tags = list('write'),
          responses = list('200' = list(description = 'OK'))
        )
      )
    )
  )
  for (api in c('one', 'two')) {
    jsonlite::write_json(
      schema,
      file.path(root, paste0(api, '.json')),
      auto_unbox = TRUE
    )
  }
  apis <- data.frame(
    schema = c('one.json', 'two.json'),
    api = c('one', 'two'),
    base_url = c('https://one.invalid', 'https://two.invalid'),
    include = TRUE
  )
  specmill::initialize_client(
    root,
    apis,
    package = 'groupclient',
    title = 'API Groups',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'test@example.org'
    ),
    license = 'MIT + file LICENSE'
  )
  read <- function(file) {
    yaml::read_yaml(file.path(root, file), handlers = list(seq = function(x) x))
  }
  put <- function(file, x) yaml::write_yaml(x, file.path(root, file))
  project <- read('specmill.yml')
  stopifnot(identical(
    unlist(project$services),
    c('apis/one.yml', 'apis/two.yml')
  ))
  one <- read('apis/one.yml')
  two <- read('apis/two.yml')
  stopifnot(
    length(one$groups) == 2L,
    length(two$groups) == 2L,
    is.null(one$groups$one_read$schemas),
    one$helper == 'one_request'
  )
  run <- function() {
    specmill::generate_client(root, config = 'specmill.yml', mode = 'plan')
  }
  hashes <- function() {
    tools::md5sum(list.files(
      root,
      recursive = TRUE,
      all.files = TRUE,
      full.names = TRUE
    ))
  }
  before <- hashes()
  baseline <- run()
  stopifnot(length(baseline$operations) == 4L, identical(before, hashes()))
  project$selection$methods <- list('GET', 'POST')
  project$defaults$batch$max_bytes <- 100L
  put('specmill.yml', project)
  one$selection$methods <- list('GET')
  one$defaults$batch$max_bytes <- 50L
  one$groups$one_read$defaults$batch <- list(max_bytes = 25L)
  put('apis/one.yml', one)
  plan <- run()
  excluded <- Filter(function(x) x$key == 'POST /items', plan$excluded)
  stopifnot(
    length(plan$operations) == 3L,
    length(excluded) == 1L,
    excluded[[1L]]$service == 'one_write',
    grepl('API methods: one', excluded[[1L]]$reason)
  )
  loaded <- specmill::load_project(root)
  stopifnot(
    loaded$services$one_read$defaults$batch$max_bytes == 25L,
    loaded$services$one_write$defaults$batch$max_bytes == 50L,
    loaded$services$two_read$defaults$batch$max_bytes == 100L
  )
  one$selection$exclude <- list('^/items$')
  put('apis/one.yml', one)
  plan <- run()
  stopifnot(
    length(plan$operations) == 2L,
    all(vapply(
      plan$operations,
      function(x) startsWith(x$service, 'two_'),
      logical(1)
    )),
    all(vapply(
      plan$excluded,
      function(x) grepl('API one exclusion', x$reason),
      logical(1)
    ))
  )
  # A group can narrow further, but cannot undo its API's exclusion.
  two$groups$two_write$selection$methods <- list('GET')
  put('apis/two.yml', two)
  plan <- run()
  stopifnot(
    length(plan$operations) == 1L,
    any(vapply(
      plan$excluded,
      function(x) x$reason == 'Prohibited by service methods',
      logical(1)
    ))
  )
  project$selection$methods <- list('POST')
  put('specmill.yml', project)
  stopifnot(length(run()$operations) == 0L)
  # Flat files still load alongside nested API containers with identical IDs.
  project$selection$methods <- list('GET', 'POST')
  flat <- two$groups$two_read
  flat$id <- 'two_read'
  flat$schemas <- two$schemas
  flat$helper <- two$helper
  put('apis/flat.yml', flat)
  two$groups$two_read <- NULL
  put('apis/two.yml', two)
  project$services <- c(project$services, list('apis/flat.yml'))
  put('specmill.yml', project)
  stopifnot(length(run()$operations) == 1L)
  fails <- function(x) {
    stopifnot(inherits(tryCatch(force(x), error = identity), 'error'))
  }
  for (bad in list(
    list(methods = 'GET'),
    list(methods = list('BAD')),
    list(exclude = list('[')),
    list(include = list('GET /items'))
  )) {
    invalid <- one
    invalid$selection <- bad
    put('apis/one.yml', invalid)
    fails(specmill::load_project(root))
  }
  invalid <- one
  invalid$groups <- list()
  put('apis/one.yml', invalid)
  fails(specmill::load_project(root))
  invalid <- one
  invalid$groups$one_read$unknown <- TRUE
  put('apis/one.yml', invalid)
  fails(specmill::load_project(root))
  put('apis/one.yml', one)
  project$services <- c(project$services, list('apis/duplicate.yml'))
  put('apis/duplicate.yml', one)
  put('specmill.yml', project)
  fails(specmill::load_project(root))
  cat(
    'API configuration: one file per API, nested tags, isolated inheritance, flat compatibility, validation and read-only plans passed.\n'
  )
}
if (sys.nframe() == 0L) {
  api_configuration_acceptance()
}
