native_transport_acceptance <- function() {
  root <- tempfile('native-transport-')
  port_file <- tempfile('transport-port-')
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
                method = req$REQUEST_METHOD,
                path = req$PATH_INFO,
                query = req$QUERY_STRING,
                key = req$HTTP_API_KEY,
                authorization = req$HTTP_AUTHORIZATION,
                type = req$CONTENT_TYPE,
                bytes = as.integer(req$rook.input$read())
              ),
              auto_unbox = TRUE,
              null = 'null'
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
  # Authentication has its own HTTP contracts; isolate native serialization here.
  schema <- file.path(dirname(port_file), paste0(basename(port_file), '.json'))
  on.exit(unlink(schema), add = TRUE)
  document <- jsonlite::read_json(system.file(
    'configuration/petstore.json',
    package = 'specmill'
  ))
  document$components$securitySchemes <- NULL
  for (path in names(document$paths)) {
    for (method in names(document$paths[[path]])) {
      document$paths[[path]][[method]]$security <- NULL
    }
  }
  jsonlite::write_json(document, schema, auto_unbox = TRUE)
  specmill::initialize_client(
    root,
    schema,
    package = 'transportclient',
    title = 'Transport Test',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'test@example.org'
    ),
    license = 'MIT + file LICENSE',
    base_url = paste0('http://127.0.0.1:', readLines(port_file)),
    naming = 'tag_prefix'
  )
  result <- specmill::generate_client(
    root,
    config = 'specmill.yml',
    mode = 'apply'
  )
  stopifnot(length(result$operations) == 19L, !length(result$diagnostics))
  specmill::generate_client(root, config = 'specmill.yml', mode = 'check')
  runtime <- new.env(parent = baseenv())
  for (file in list.files(file.path(root, 'R'), full.names = TRUE)) {
    sys.source(file, runtime)
  }
  result <- runtime$pet_find_by_tags(c('a/b', 'blue sky'))
  stopifnot(result$query == '?tags=a%2Fb&tags=blue%20sky')
  result <- runtime$pet_find_by_tags('one')
  stopifnot(result$query == '?tags=one')
  result <- runtime$pet_delete(petId = 10, api_key = 'fixture-only-key')
  stopifnot(result$key == 'fixture-only-key', result$method == 'DELETE')
  result <- runtime$pet_delete(petId = 10)
  stopifnot(is.null(result$key), is.null(result$authorization))
  result <- runtime$store_get_inventory()
  stopifnot(is.null(result$key), is.null(result$authorization))
  bytes <- as.raw(c(0, 1, 127, 255))
  result <- runtime$pet_upload_file(10, body = bytes)
  stopifnot(
    identical(unlist(result$bytes), as.integer(bytes)),
    result$type == 'application/octet-stream',
    result$method == 'POST'
  )
  stopifnot(inherits(
    try(runtime$pet_upload_file(10, body = 'not bytes'), silent = TRUE),
    'try-error'
  ))
  stopifnot(inherits(
    try(runtime$pet_find_by_tags(c('a', NA_character_)), silent = TRUE),
    'try-error'
  ))
  # The same generated query contract supports non-exploded arrays.
  parsed <- specmill::read_operations(system.file(
    'configuration/petstore.json',
    package = 'specmill'
  ))
  fixtures <- specmill::operation_fixtures(parsed$operations)
  stopifnot(
    length(fixtures) == 19L,
    is.raw(fixtures$uploadFile$body),
    is.character(fixtures$findPetsByTags$tags)
  )
  op <- parsed$operations$findPetsByTags
  op$parameters[[1L]]$explode <- FALSE
  eval(
    parse(text = specmill::render_operation(op, list(helper = 'api_request'))),
    runtime
  )
  result <- runtime$findPetsByTags(c('first', 'second'))
  stopifnot(grepl('tags=first(%2C|,)second$', result$query))
  # Old helpers fail validation instead of silently dropping new transport fields.
  writeLines(
    'api_request <- function(method, path, path_params, query, body) NULL',
    file.path(root, 'R/api_request.R')
  )
  error <- tryCatch(
    specmill::generate_client(root, config = 'specmill.yml', mode = 'plan'),
    error = identity
  )
  stopifnot(
    inherits(error, 'error'),
    grepl('Unknown helper arguments', conditionMessage(error))
  )
  cat(
    'Native transport: 19 generated endpoints, repeated/comma query arrays, optional headers, public requests, exact binary bytes and helper compatibility passed.\n'
  )
}
if (sys.nframe() == 0L) {
  native_transport_acceptance()
}
