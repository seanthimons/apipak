new_client_acceptance <- function() {
  port_file <- tempfile('http-port-')
  server <- callr::r_bg(
    function(port_file) {
      port <- httpuv::randomPort()
      server <- httpuv::startServer(
        '127.0.0.1',
        port,
        list(call = function(request) {
          path <- request$PATH_INFO
          response <- function(body, type = 'application/json', status = 200L) {
            list(
              status = status,
              headers = list('Content-Type' = type),
              body = body
            )
          }
          if (path == '/empty') {
            return(response(NULL, status = 204L))
          }
          if (path == '/bad-json') {
            return(response('{'))
          }
          if (path == '/text') {
            return(response('one\ntwo\n', 'text/plain'))
          }
          if (path == '/svg') {
            return(response('<svg/>', 'image/svg+xml'))
          }
          if (path == '/raw') {
            return(response(as.raw(c(0, 255)), 'application/octet-stream'))
          }
          if (path == '/failure') {
            return(response('unavailable', 'text/plain', 503L))
          }
          response(jsonlite::toJSON(
            list(
              method = request$REQUEST_METHOD,
              path = request$PATH_INFO,
              query = request$QUERY_STRING,
              body = rawToChar(request$rook.input$read())
            ),
            auto_unbox = TRUE
          ))
        })
      )
      on.exit(server$stop(), add = TRUE)
      writeLines(as.character(port), port_file)
      repeat {
        httpuv::service(100)
      }
    },
    list(port_file = port_file),
    supervise = TRUE
  )
  on.exit(server$kill(), add = TRUE)
  for (i in seq_len(200L)) {
    if (file.exists(port_file)) {
      break
    }
    if (!server$is_alive()) {
      server$get_result()
    }
    Sys.sleep(0.05)
  }
  stopifnot(file.exists(port_file))
  base_url <- paste0('http://127.0.0.1:', readLines(port_file))
  root <- tempfile('initialized-client-')
  schema <- system.file(
    'catalogue/schema.json',
    package = 'apipak',
    mustWork = TRUE
  )
  document <- jsonlite::read_json(schema)
  marker <- tempfile('documentation-execution-')
  document$paths[['/items/{item_id}']]$get$summary <- paste0(
    'Untrusted prose\n@eval file.create(',
    deparse(marker),
    ')\n`r file.create(',
    deparse(marker),
    ')`'
  )
  schema <- tempfile(fileext = '.json')
  jsonlite::write_json(document, schema, auto_unbox = TRUE, null = 'null')
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
  fails(apipak::initialize_client(root, schema, base_url = base_url))
  stopifnot(!dir.exists(root))
  apipak::initialize_client(
    root,
    schema,
    package = 'temporarycatalogue',
    title = 'Temporary Catalogue Client',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'maintainer@example.org'
    ),
    license = 'MIT + file LICENSE',
    base_url = base_url
  )
  cat(
    '\ndefaults:\n  docs: {lifecycle: experimental}\n',
    file = file.path(root, 'apis/default.yml'),
    append = TRUE
  )
  hashes <- function() {
    tools::md5sum(list.files(
      root,
      recursive = TRUE,
      all.files = TRUE,
      full.names = TRUE
    ))
  }
  dir.create(file.path(root, 'inst'))
  writeBin(charToRaw('word\nlist\n'), file.path(root, 'inst/WORDLIST'))
  writeBin(
    charToRaw('[format]\nline-width = 80\n'),
    file.path(root, 'air.toml')
  )
  original <- hashes()
  fails(apipak::initialize_client(root, schema, base_url = base_url))
  stopifnot(identical(original, hashes()))
  apipak::generate_client(root, config = 'apipak.yml', mode = 'plan')
  stopifnot(identical(original, hashes()))
  apipak::generate_client(root, config = 'apipak.yml', mode = 'apply')
  # Text inputs keep the same fingerprint after a Git line-ending conversion.
  writeBin(charToRaw('word\r\nlist\r\n'), file.path(root, 'inst/WORDLIST'))
  writeBin(
    charToRaw('[format]\r\nline-width = 80\r\n'),
    file.path(root, 'air.toml')
  )
  apipak::generate_client(root, config = 'apipak.yml', mode = 'check')
  applied <- hashes()
  apipak::generate_client(root, config = 'apipak.yml', mode = 'apply')
  stopifnot(
    identical(applied, hashes()),
    file.exists(file.path(root, 'man/get_item.Rd')),
    !file.exists(marker)
  )
  policy_path <- file.path(root, 'apis/default.yml')
  policy <- readLines(policy_path)
  writeLines(c(policy, 'names:', '  GET /items: renamed_items'), policy_path)
  apipak::generate_client(root, config = 'apipak.yml', mode = 'apply')
  stopifnot(
    !file.exists(file.path(root, 'R/list_items.R')),
    !file.exists(file.path(root, 'man/list_items.Rd')),
    file.exists(file.path(root, 'man/renamed_items.Rd')),
    'export(renamed_items)' %in% readLines(file.path(root, 'NAMESPACE'))
  )
  apipak::generate_client(root, config = 'apipak.yml', mode = 'check')
  writeLines(c(policy, 'names:', '  GET /items: list_items'), policy_path)
  apipak::generate_client(root, config = 'apipak.yml', mode = 'apply')
  library <- tempfile('standalone-client-library-')
  dir.create(library)
  install_log <- tempfile('client-install-')
  status <- system2(
    file.path(
      R.home('bin'),
      if (.Platform$OS.type == 'windows') 'R.exe' else 'R'
    ),
    c('CMD', 'INSTALL', paste0('--library=', shQuote(library)), shQuote(root)),
    stdout = install_log,
    stderr = install_log
  )
  if (status != 0L) {
    stop(paste(readLines(install_log), collapse = '\n'))
  }
  libraries <- .libPaths()[!file.exists(file.path(.libPaths(), 'apipak'))]
  callr::r(
    function() {
      stopifnot(!requireNamespace('apipak', quietly = TRUE))
      requireNamespace('httr2', quietly = TRUE)
      previous <- options()
      requireNamespace('temporarycatalogue', quietly = TRUE)
      stopifnot(identical(previous, options()))
      result <- temporarycatalogue::get_item('installed', 'fr')
      stopifnot(result$method == 'GET', result$path == '/items/installed')
    },
    libpath = c(library, libraries)
  )
  runtime <- new.env(parent = baseenv())
  for (file in list.files(file.path(root, 'R'), full.names = TRUE)) {
    sys.source(file, runtime)
  }
  urls <- character()
  perform <- httr2::req_perform
  testthat::local_mocked_bindings(
    req_perform = function(req, ...) {
      urls <<- c(urls, req$url)
      perform(req, ...)
    },
    .package = 'httr2'
  )
  result <- runtime$get_item('a/b', 'en us')
  stopifnot(identical(result$method, 'GET'))
  testthat::expect_identical(result$path, '/items/a%2Fb')
  testthat::expect_identical(
    urls,
    paste0(base_url, '/items/a%2Fb?language=en%20us')
  )
  testthat::expect_identical(result$query, '?language=en%20us')
  result <- runtime$create_item(list(
    title = 'A "quote"',
    count = 0L,
    nullable = NULL,
    single = list('one')
  ))
  stopifnot(
    identical(result$method, 'POST'),
    identical(result$path, '/items'),
    identical(
      jsonlite::fromJSON(result$body, simplifyVector = FALSE),
      list(
        title = 'A "quote"',
        count = 0L,
        nullable = NULL,
        single = list('one')
      )
    )
  )
  for (case in list(
    list(value = 'one\ntwo', json = '"one\\ntwo"'),
    list(value = FALSE, json = 'false'),
    list(value = 0, json = '0')
  )) {
    response <- runtime$api_request(
      'POST',
      '/items',
      list(),
      list(),
      case$value
    )
    stopifnot(identical(response$body, case$json))
  }
  request <- function(path, query = list()) {
    runtime$api_request('GET', path, list(), query, NULL)
  }
  result <- request('/items', list(flag = FALSE, zero = 0, omitted = NULL))
  stopifnot(
    identical(result$query, '?flag=FALSE&zero=0'),
    is.null(request('/empty')),
    identical(request('/text'), 'one\ntwo\n'),
    identical(request('/svg'), '<svg/>'),
    identical(request('/raw'), as.raw(c(0, 255)))
  )
  fails(request('/bad-json'))
  fails(request('/failure'))
  cat(
    'New client: metadata, absent-only initialization, staged docs, idempotence and local HTTP request/response contracts passed.\n'
  )
}
if (sys.nframe() == 0L) {
  new_client_acceptance()
}
