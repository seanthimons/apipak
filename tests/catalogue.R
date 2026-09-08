catalogue_acceptance <- function() {
  fixture <- system.file('catalogue', package = 'apipak', mustWork = TRUE)
  root <- tempfile('catalogue-client-')
  dir.create(root)
  file.copy(list.files(fixture, full.names = TRUE), root, recursive = TRUE)
  old <- setwd(tempdir())
  on.exit(setwd(old), add = TRUE)
  spec <- list(
    files = file.path(root, 'schema.json'),
    helper = 'catalogue_request',
    hooks = list(
      get_item = list(
        pre_request = 'normalize_input',
        post_response = 'extract_output'
      )
    ),
    policy_version = 'catalogue-1'
  )
  spec$package <- 'localcatalogue'
  spec$response_fixture <- list(data = 'ok')
  spec$contracts <- list(
    get_item = list(
      inputs = list(item_id = ' a/b ', language = 'fr'),
      request = list(
        method = 'GET',
        path = '/items/{item_id}',
        path_params = list(item_id = 'a/b'),
        query = list(language = 'fr'),
        body = NULL
      ),
      result = 'ok'
    ),
    create_item = list(
      inputs = list(body = list(title = 'Example')),
      request = list(
        method = 'POST',
        path = '/items',
        path_params = list(),
        query = list(),
        body = list(title = 'Example')
      ),
      result = list(data = 'ok')
    ),
    refresh = list(
      inputs = list(),
      request = list(
        method = 'POST',
        path = '/refresh',
        path_params = list(),
        query = list(),
        body = NULL
      ),
      result = list(data = 'ok')
    ),
    list_items = list(
      inputs = list(page = 2L),
      request = list(
        method = 'GET',
        path = '/items',
        path_params = list(),
        query = list(page = 2L),
        body = NULL
      ),
      result = list(data = 'ok')
    )
  )
  manual <- tools::md5sum(file.path(root, 'R/helper.R'))
  first <- apipak::generate_client(root, spec, 'apply')
  stopifnot(length(first$operations) == 4L, length(first$diagnostics) == 0L)
  second <- apipak::generate_client(root, spec, 'apply')
  stopifnot(
    all(vapply(second$files, function(f) f$action == 'unchanged', logical(1))),
    identical(manual, tools::md5sum(file.path(root, 'R/helper.R')))
  )
  library_dir <- tempfile('catalogue-library-')
  dir.create(library_dir)
  profile <- Sys.getenv('R_PROFILE_USER', unset = NA_character_)
  on.exit(
    if (is.na(profile)) {
      Sys.unsetenv('R_PROFILE_USER')
    } else {
      Sys.setenv(R_PROFILE_USER = profile)
    },
    add = TRUE
  )
  Sys.setenv(R_PROFILE_USER = '')
  r_tests <- Sys.getenv('R_TESTS', unset = NA_character_)
  on.exit(
    if (is.na(r_tests)) {
      Sys.unsetenv('R_TESTS')
    } else {
      Sys.setenv(R_TESTS = r_tests)
    },
    add = TRUE
  )
  Sys.setenv(R_TESTS = '')
  status <- system2(
    file.path(
      R.home('bin'),
      if (.Platform$OS.type == 'windows') 'R.exe' else 'R'
    ),
    c(
      'CMD',
      'INSTALL',
      paste0('--library=', shQuote(library_dir)),
      shQuote(root)
    )
  )
  stopifnot(status == 0L)
  library('localcatalogue', lib.loc = library_dir, character.only = TRUE)
  testthat::test_dir(
    file.path(root, 'tests/testthat'),
    reporter = 'summary',
    stop_on_failure = TRUE
  )
  other <- tempfile('other-catalogue-client-')
  dir.create(other)
  file.copy(
    file.path(root, c('DESCRIPTION', 'NAMESPACE', 'R')),
    other,
    recursive = TRUE
  )
  description <- readLines(file.path(other, 'DESCRIPTION'))
  writeLines(
    sub('Package: localcatalogue', 'Package: othercatalogue', description),
    file.path(other, 'DESCRIPTION')
  )
  helper_file <- file.path(other, 'R/helper.R')
  writeLines(
    gsub("'ok'", "'second'", readLines(helper_file), fixed = TRUE),
    helper_file
  )
  stopifnot(
    system2(
      file.path(
        R.home('bin'),
        if (.Platform$OS.type == 'windows') 'R.exe' else 'R'
      ),
      c(
        'CMD',
        'INSTALL',
        paste0('--library=', shQuote(library_dir)),
        shQuote(other)
      )
    ) ==
      0L
  )
  other_ns <- loadNamespace('othercatalogue', lib.loc = library_dir)
  stopifnot(
    identical(other_ns$get_item(' x '), 'second'),
    identical(localcatalogue::get_item(' x '), 'ok')
  )
  request <- function(
    method,
    path,
    path_params = list(),
    query = list(),
    body = NULL
  ) {
    list(list(
      method = method,
      path = path,
      path_params = path_params,
      query = query,
      body = body
    ))
  }
  check <- function(call, expected, result) {
    localcatalogue::clear_calls()
    apipak::check_requests(call, expected, localcatalogue::captured, result)
  }
  check(
    function() localcatalogue::get_item(' a/b ', language = 'fr'),
    request(
      'GET',
      '/items/{item_id}',
      list(item_id = 'a/b'),
      list(language = 'fr')
    ),
    'ok'
  )
  check(
    function() localcatalogue::create_item(list(title = 'Example', count = 2L)),
    request('POST', '/items', body = list(title = 'Example', count = 2L)),
    list(data = 'ok')
  )
  check(
    function() localcatalogue::refresh(),
    request('POST', '/refresh'),
    list(data = 'ok')
  )
  check(
    function() localcatalogue::list_items(page = 2L),
    request('GET', '/items', query = list(page = 2L)),
    list(data = 'ok')
  )
  fails <- function(expr) {
    stopifnot(inherits(
      tryCatch(
        {
          force(expr)
          NULL
        },
        error = identity
      ),
      'error'
    ))
  }
  fails(check(
    function() localcatalogue::refresh(),
    request('GET', '/refresh'),
    list(data = 'ok')
  ))
  fails(localcatalogue::get_item(NULL))
  fails(localcatalogue::create_item(list(count = 1L)))
  fails(check(
    function() localcatalogue::create_item(list(title = 'wrong')),
    request('POST', '/items', body = list(title = 'expected')),
    list(data = 'ok')
  ))
  testthat::with_mocked_bindings(
    fails(check(
      function() localcatalogue::get_item('x'),
      request(
        'GET',
        '/items/{item_id}',
        list(item_id = 'x'),
        list(language = NULL)
      ),
      'ok'
    )),
    extract_output = function(state) stop('intentional post-response fault'),
    .package = 'localcatalogue'
  )
  wire <- localcatalogue::wire_request(
    'POST',
    '/items/{item_id}',
    list(item_id = 'a/b'),
    list(language = 'en us'),
    list(title = 'A "quoted" title')
  )
  stopifnot(
    identical(
      wire$url,
      'https://catalogue.invalid/items/a%2Fb?language=en%20us'
    ),
    identical(wire$method, 'POST'),
    identical(wire$body$data, list(title = 'A "quoted" title')),
    identical(wire$body$type, 'json')
  )
  hooks_a <- new.env(parent = emptyenv())
  hooks_a$normalize_input <- function(x) x
  hooks_b <- new.env(parent = emptyenv())
  hooks_b$normalize_input <- function(x) stop('other client')
  config <- list(get_item = list(pre_request = 'normalize_input'))
  wrappers <- list(get_item = getExportedValue('localcatalogue', 'get_item'))
  stopifnot(
    apipak::validate_hooks(config, wrappers, hooks_a)$valid,
    apipak::validate_hooks(config, wrappers, hooks_b)$valid,
    !apipak::validate_hooks(
      config,
      wrappers,
      new.env(parent = emptyenv())
    )$valid
  )
  document <- jsonlite::fromJSON(spec$files, simplifyVector = FALSE)
  changed <- document
  changed$paths[['/items']]$get$parameters[[2L]] <- list(
    name = 'tenant',
    'in' = 'query',
    required = TRUE,
    schema = list(type = 'string')
  )
  changed_file <- tempfile(fileext = '.json')
  jsonlite::write_json(changed, changed_file, auto_unbox = TRUE)
  new <- apipak::read_operations(changed_file)
  delta <- apipak::compare_operations(
    apipak::read_operations(spec$files),
    new
  )
  stopifnot(
    any(vapply(delta, function(d) d$status == 'breaking', logical(1))),
    identical(names(first$operations), names(new$operations))
  )
  changed$components$schemas$Item$properties <- list(
    code = list(type = 'integer')
  )
  changed$components$schemas$Item$required <- list('code')
  jsonlite::write_json(changed, changed_file, auto_unbox = TRUE)
  alternate <- apipak::read_operations(changed_file)
  stopifnot(
    identical(
      names(first$operations$create_item$body$properties),
      c('title', 'count')
    ),
    identical(names(alternate$operations$create_item$body$properties), 'code')
  )
  changed$paths[['/items']]$post$requestBody$content[[
    'application/json'
  ]]$schema <- list(type = 'object', additionalProperties = TRUE)
  changed$paths[['/items']]$get$parameters[[1]]$style <- 'deepObject'
  jsonlite::write_json(changed, changed_file, auto_unbox = TRUE)
  spec$files <- changed_file
  before <- tools::md5sum(file.path(root, 'R/create_item.R'))
  unsupported <- apipak::generate_client(root, spec, 'apply')
  stopifnot(
    length(unsupported$diagnostics) == 2L,
    identical(before, tools::md5sum(file.path(root, 'R/create_item.R')))
  )
  fails(apipak::apply_files(
    root,
    list('../escape.R' = 'x <- 1'),
    mode = 'apply'
  ))
  fails(apipak::apply_files(
    root,
    list('R/get_item.R' = 'invalid ('),
    mode = 'apply'
  ))
  protected <- apipak::apply_files(
    root,
    list('R/helper.R' = 'stop("overwrite")'),
    mode = 'apply'
  )
  stopifnot(
    protected[[1]]$action == 'protected',
    identical(manual, tools::md5sum(file.path(root, 'R/helper.R')))
  )
  # Runtime package metadata and namespaces contain no toolkit dependency.
  stopifnot(
    !'apipak' %in% names(getNamespaceImports('localcatalogue')),
    !'apipak' %in%
      unlist(tools::package_dependencies(
        'localcatalogue',
        db = installed.packages(lib.loc = library_dir)
      ))
  )
  cat(
    'Catalogue: requests, four faults, wire mapping, hooks, references, diff, ownership and installed runtime passed.\n'
  )
  invisible(list(root = root, library = library_dir))
}
if (sys.nframe() == 0L) {
  options(error = function() {
    traceback(3)
    quit(status = 1L)
  })
  catalogue_acceptance()
}
