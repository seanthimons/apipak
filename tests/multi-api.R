multi_api_acceptance <- function() {
  root <- tempfile('multi-api-')
  dir.create(root)
  port_file <- tempfile('multi-api-port-')
  on.exit(unlink(c(root, port_file), recursive = TRUE), add = TRUE)
  server <- callr::r_bg(
    function(port_file) {
      port <- httpuv::randomPort()
      server <- httpuv::startServer(
        '127.0.0.1',
        port,
        list(call = function(req) {
          list(
            status = 200L,
            headers = list('Content-Type' = 'application/json'),
            body = jsonlite::toJSON(
              list(
                path = req$PATH_INFO,
                key = req$HTTP_X_KEY,
                bytes = as.integer(req$rook.input$read())
              ),
              auto_unbox = TRUE
            )
          )
        })
      )
      on.exit(server$stop(), add = TRUE)
      writeLines(as.character(port), port_file)
      repeat {
        httpuv::service(100)
      }
    },
    list(port_file),
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
  base <- paste0('http://127.0.0.1:', readLines(port_file))
  schema <- function(title, path) {
    list(
      openapi = '3.0.3',
      info = list(title = title, version = '1'),
      servers = list(list(url = paste0(base, path))),
      components = list(
        securitySchemes = list(
          key = list(type = 'apiKey', name = 'X-Key', 'in' = 'header')
        )
      ),
      paths = list(
        '/items' = list(
          post = list(
            operationId = 'send',
            tags = list('items'),
            security = list(list(key = list())),
            requestBody = list(
              required = TRUE,
              content = list(
                'application/json' = list(
                  schema = list(
                    type = 'array',
                    maxItems = 2L,
                    items = list(type = 'string')
                  )
                )
              )
            ),
            responses = list('200' = list(description = 'OK'))
          )
        )
      )
    )
  }
  one <- schema('First API', '/one')
  one$paths[['/items']]$post$tags <- list('')
  one$paths[['/status']] <- list(
    get = list(
      operationId = 'status',
      responses = list('200' = list(description = 'OK'))
    )
  )
  two <- schema('Second API', '/two')
  jsonlite::write_json(one, file.path(root, 'random1.json'), auto_unbox = TRUE)
  jsonlite::write_json(two, file.path(root, 'random2.json'), auto_unbox = TRUE)
  jsonlite::write_json(
    one[rev(names(one))],
    file.path(root, 'duplicate.json'),
    auto_unbox = TRUE,
    pretty = TRUE
  )
  apis <- specmill::configure_apis(root, review = FALSE)
  stopifnot(
    nrow(apis) == 3L,
    sum(apis$include) == 2L,
    setequal(apis$api[apis$include], c('first', 'second')),
    !file.exists(file.path(root, 'specmill-apis.yml'))
  )
  apis <- specmill::configure_apis(root, review = FALSE, mode = 'apply')
  first_schema <- apis$schema[apis$include & apis$api == 'first']
  choices <- data.frame(schema = first_schema, api = 'renamed')
  saved <- specmill::configure_apis(
    root,
    choices = choices,
    review = FALSE,
    mode = 'apply'
  )
  repeated <- specmill::configure_apis(root, review = FALSE)
  stopifnot(identical(saved$api, repeated$api))
  specmill::initialize_client(
    root,
    repeated,
    package = 'multitest',
    title = 'Multiple APIs',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'test@example.org'
    ),
    license = 'MIT + file LICENSE'
  )
  project_path <- file.path(root, 'specmill.yml')
  project <- yaml::read_yaml(project_path, handlers = list(seq = function(x) x))
  project$defaults$batch <- list(max_items = 1L, max_bytes = 64L)
  yaml::write_yaml(project, project_path)
  plan <- specmill::generate_client(
    root,
    config = 'specmill.yml',
    mode = 'plan'
  )
  stopifnot(length(plan$operations) == 3L, !length(plan$diagnostics))
  specmill::generate_client(root, config = 'specmill.yml', mode = 'apply')
  specmill::generate_client(root, config = 'specmill.yml', mode = 'check')
  runtime <- new.env(parent = baseenv())
  for (file in list.files(file.path(root, 'R'), full.names = TRUE)) {
    sys.source(file, runtime)
  }
  withr::local_envvar(c(MULTITEST_RENAMED_KEY = NA, MULTITEST_SECOND_KEY = NA))
  stopifnot(runtime$renamed_status()$path == '/one/status')
  fails <- function(expr) {
    stopifnot(inherits(tryCatch(force(expr), error = identity), 'error'))
  }
  fails(runtime$renamed_send(list('a')))
  runtime$set_api_token('fixture-one', scheme = 'renamed.key')
  fails(runtime$second_send(list('b')))
  runtime$set_api_token('fixture-two', scheme = 'second.key')
  first <- runtime$renamed_send(list('a', 'b'))
  second <- runtime$second_send(list('c'))
  stopifnot(
    first$path == '/one/items',
    second$path == '/two/items',
    first$key == 'fixture-one',
    second$key == 'fixture-two'
  )
  fails(runtime$renamed_send(list('a', 'b', 'c')))
  fails(runtime$renamed_request(
    'POST',
    '/items',
    list(),
    list(),
    list('abc'),
    batch = list(max_bytes = 2)
  ))
  bytes <- runtime$renamed_request(
    'POST',
    '/items',
    list(),
    list(),
    list('abc'),
    batch = list(max_bytes = 20)
  )$bytes
  stopifnot(rawToChar(as.raw(unlist(bytes))) == '["abc"]')
  cat(
    'Multi API: catalogue reuse, duplicate detection, routing, independent credentials and batch limits passed.\n'
  )
}
if (sys.nframe() == 0L) {
  multi_api_acceptance()
}
