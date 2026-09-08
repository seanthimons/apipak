catalogue_acceptance <- function() {
  fixture <- system.file('catalogue', package = 'wrapmaint', mustWork = TRUE)
  root <- tempfile('catalogue-client-')
  dir.create(root)
  file.copy(list.files(fixture, full.names = TRUE), root, recursive = TRUE)
  old <- setwd(tempdir())
  on.exit(setwd(old), add = TRUE)
  spec <- list(files = file.path(root, 'schema.json'), helper = 'catalogue_request',
    hooks = list(get_item = list(pre_request = 'normalize_input', post_response = 'extract_output')),
    policy_version = 'catalogue-1')
  manual <- tools::md5sum(file.path(root, 'R/helper.R'))
  first <- wrapmaint::generate_client(root, spec, 'apply')
  stopifnot(length(first$operations) == 4L, length(first$diagnostics) == 0L)
  second <- wrapmaint::generate_client(root, spec, 'apply')
  stopifnot(all(vapply(second$files, function(f) f$action == 'unchanged', logical(1))),
    identical(manual, tools::md5sum(file.path(root, 'R/helper.R'))))
  library_dir <- tempfile('catalogue-library-')
  dir.create(library_dir)
  status <- system2(file.path(R.home('bin'), 'R.exe'), c('CMD', 'INSTALL', paste0('--library=', shQuote(library_dir)), shQuote(root)))
  stopifnot(status == 0L)
  library('localcatalogue', lib.loc = library_dir, character.only = TRUE)
  request <- function(method, path, path_params = list(), query = list(), body = NULL) {
    list(list(method = method, path = path, path_params = path_params, query = query, body = body))
  }
  check <- function(call, expected, result) {
    localcatalogue::clear_calls()
    wrapmaint::check_requests(call, expected, localcatalogue::captured, result)
  }
  check(function() localcatalogue::get_item(' a/b ', language = 'fr'),
    request('GET', '/items/{item_id}', list(item_id = 'a/b'), list(language = 'fr')), 'ok')
  check(function() localcatalogue::create_item(list(title = 'Example', count = 2L)),
    request('POST', '/items', body = list(title = 'Example', count = 2L)), list(data = 'ok'))
  check(function() localcatalogue::refresh(), request('POST', '/refresh'), list(data = 'ok'))
  check(function() localcatalogue::list_items(page = 2L), request('GET', '/items', query = list(page = 2L)), list(data = 'ok'))
  fails <- function(expr) stopifnot(inherits(tryCatch({ force(expr); NULL }, error = identity), 'error'))
  fails(check(function() localcatalogue::refresh(), request('GET', '/refresh'), list(data = 'ok')))
  fails(localcatalogue::get_item(NULL))
  fails(localcatalogue::create_item(list(count = 1L)))
  fails(check(function() localcatalogue::create_item(list(title = 'wrong')),
    request('POST', '/items', body = list(title = 'expected')), list(data = 'ok')))
  testthat::with_mocked_bindings(
    fails(check(function() localcatalogue::get_item('x'), request('GET', '/items/{item_id}',
      list(item_id = 'x'), list(language = NULL)), 'ok')),
    extract_output = function(state) stop('intentional post-response fault'), .package = 'localcatalogue')
  wire <- localcatalogue::wire_request('POST', '/items/{item_id}', list(item_id = 'a/b'),
    list(language = 'en us'), list(title = 'A "quoted" title'))
  stopifnot(identical(wire$url, 'https://catalogue.invalid/items/a%2Fb?language=en%20us'),
    identical(wire$method, 'POST'), identical(wire$body$data, list(title = 'A "quoted" title')),
    identical(wire$body$type, 'json'))
  hooks_a <- new.env(parent = emptyenv()); hooks_a$normalize_input <- function(x) x
  hooks_b <- new.env(parent = emptyenv()); hooks_b$normalize_input <- function(x) stop('other client')
  config <- list(get_item = list(pre_request = 'normalize_input'))
  wrappers <- list(get_item = getExportedValue('localcatalogue', 'get_item'))
  stopifnot(wrapmaint::validate_hooks(config, wrappers, hooks_a)$valid,
    wrapmaint::validate_hooks(config, wrappers, hooks_b)$valid,
    !wrapmaint::validate_hooks(config, wrappers, new.env(parent = emptyenv()))$valid)
  document <- jsonlite::fromJSON(spec$files, simplifyVector = FALSE)
  changed <- document
  changed$paths[['/items']]$get$parameters[[2L]] <- list(name = 'tenant', 'in' = 'query',
    required = TRUE, schema = list(type = 'string'))
  changed_file <- tempfile(fileext = '.json')
  jsonlite::write_json(changed, changed_file, auto_unbox = TRUE)
  new <- wrapmaint::read_operations(changed_file)
  delta <- wrapmaint::compare_operations(wrapmaint::read_operations(spec$files), new)
  stopifnot(any(vapply(delta, function(d) d$status == 'breaking', logical(1))),
    identical(names(first$operations), names(new$operations)))
  changed$components$schemas$Item$properties <- list(code = list(type = 'integer'))
  changed$components$schemas$Item$required <- list('code')
  jsonlite::write_json(changed, changed_file, auto_unbox = TRUE)
  alternate <- wrapmaint::read_operations(changed_file)
  stopifnot(identical(names(first$operations$create_item$body$properties), c('title', 'count')),
    identical(names(alternate$operations$create_item$body$properties), 'code'))
  changed$paths[['/items']]$post$requestBody$content[['application/json']]$schema <- list(type = 'object', additionalProperties = TRUE)
  changed$paths[['/items']]$get$parameters[[1]]$style <- 'deepObject'
  jsonlite::write_json(changed, changed_file, auto_unbox = TRUE)
  spec$files <- changed_file
  before <- tools::md5sum(file.path(root, 'R/create_item.R'))
  unsupported <- wrapmaint::generate_client(root, spec, 'apply')
  stopifnot(length(unsupported$diagnostics) == 2L, identical(before, tools::md5sum(file.path(root, 'R/create_item.R'))))
  fails(wrapmaint::apply_files(root, list('../escape.R' = 'x <- 1'), mode = 'apply'))
  fails(wrapmaint::apply_files(root, list('R/get_item.R' = 'invalid ('), mode = 'apply'))
  protected <- wrapmaint::apply_files(root, list('R/helper.R' = 'stop("overwrite")'), mode = 'apply')
  stopifnot(protected[[1]]$action == 'protected', identical(manual, tools::md5sum(file.path(root, 'R/helper.R'))))
  # Runtime package metadata and namespaces contain no toolkit dependency.
  stopifnot(!'wrapmaint' %in% names(getNamespaceImports('localcatalogue')),
    !'wrapmaint' %in% unlist(tools::package_dependencies('localcatalogue', db = installed.packages(lib.loc = library_dir))))
  cat('Catalogue: requests, four faults, wire mapping, hooks, references, diff, ownership and installed runtime passed.\n')
  invisible(list(root = root, library = library_dir))
}
if (sys.nframe() == 0L) {
  options(error = function() { traceback(3); quit(status = 1L) })
  catalogue_acceptance()
}
