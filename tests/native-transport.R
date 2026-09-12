native_transport_acceptance <- function(extra_checks = NULL) {
  root <- tempfile('native-transport-')
  port_file <- tempfile('transport-port-')
  on.exit(unlink(c(root, port_file), recursive = TRUE), add = TRUE)
  server <- callr::r_bg(
    function(port_file) {
      port <- httpuv::randomPort()
      request_number <- 0L
      server <- httpuv::startServer(
        '127.0.0.1',
        port,
        list(call = function(req) {
          request_number <<- request_number + 1L
          list(
            status = 200L,
            headers = list('Content-Type' = 'application/json'),
            body = jsonlite::toJSON(
              list(
                method = req$REQUEST_METHOD,
                request_number = request_number,
                path = req$PATH_INFO,
                query = req$QUERY_STRING,
                parameter_header = req$HTTP_X_TEST,
                cookie = req$HTTP_COOKIE,
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
  if (!is.null(extra_checks)) {
    extra_checks(runtime, root)
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
  # Exercise open JSON shapes through the same real localhost transport.
  empty <- setNames(list(), character())
  shapes <- list(
    open = list(type = 'object'),
    explicit_open = list(type = 'object', additionalProperties = TRUE),
    closed_empty = list(type = 'object', additionalProperties = FALSE),
    mixed = list(
      type = 'object',
      properties = list(id = list(type = 'string')),
      additionalProperties = list(type = 'integer')
    ),
    map = list(type = 'object', additionalProperties = list(type = 'integer')),
    array = list(type = 'array', items = empty),
    any = empty,
    closed = list(
      type = 'object',
      additionalProperties = FALSE,
      required = list('id'),
      properties = list(
        id = list(type = 'integer'),
        note = list(type = 'string', nullable = TRUE)
      )
    ),
    nested = list(
      type = 'object',
      properties = list(
        map = list(
          type = 'object',
          additionalProperties = list(type = 'array', items = empty)
        )
      )
    ),
    nullable = list(type = 'object', nullable = TRUE),
    required = list(type = 'object', required = list('anything')),
    example = list(example = list(id = 1L))
  )
  document$paths <- lapply(names(shapes), function(name) {
    list(
      post = list(
        operationId = paste0('json_', name),
        requestBody = list(
          required = name == 'required',
          content = list('application/json' = list(schema = shapes[[name]]))
        ),
        responses = list('200' = list(description = 'OK'))
      )
    )
  })
  names(document$paths) <- paste0('/', names(shapes))
  jsonlite::write_json(document, schema, auto_unbox = TRUE, null = 'null')
  parsed <- specmill::read_operations(schema)
  stopifnot(
    !length(parsed$diagnostics),
    length(parsed$operations) == length(shapes)
  )
  fixtures <- specmill::operation_fixtures(parsed$operations)
  for (op in parsed$operations) {
    eval(
      parse(
        text = specmill::render_operation(op, list(helper = 'api_request'))
      ),
      runtime
    )
  }
  wire <- function(result) rawToChar(as.raw(unlist(result$bytes)))
  stopifnot(
    wire(runtime$json_open(list())) == '{}',
    wire(runtime$json_explicit_open(empty)) == '{}',
    wire(runtime$json_closed_empty(list())) == '{}',
    wire(runtime$json_mixed(list(id = 'x', extra = 1L))) ==
      '{"id":"x","extra":1}',
    wire(runtime$json_array(list())) == '[]',
    wire(runtime$json_any(empty)) == '{}',
    wire(runtime$json_any(list())) == '[]',
    wire(runtime$json_any(NULL)) == 'null',
    wire(runtime$json_nullable(NULL)) == 'null',
    wire(runtime$json_nullable()) == '',
    wire(runtime$json_open()) == '',
    wire(runtime$json_map(list(a = 1L, b = 2L))) == '{"a":1,"b":2}',
    wire(runtime$json_closed(list(id = 1L))) == '{"id":1}',
    wire(runtime$json_closed(list(id = 1L, note = NULL))) ==
      '{"id":1,"note":null}',
    wire(runtime$json_required(list(anything = NULL))) == '{"anything":null}',
    wire(runtime$json_example(FALSE)) == 'false',
    wire(runtime$json_array(list(
      1L,
      'x',
      FALSE,
      NULL,
      empty,
      list(),
      list(2L)
    ))) ==
      '[1,"x",false,null,{},[],[2]]',
    wire(runtime$json_nested(list(
      map = list(a = list(NULL, empty, list()))
    ))) ==
      '{"map":{"a":[null,{},[]]}}'
  )
  for (name in names(fixtures)) {
    do.call(runtime[[name]], fixtures[[name]])
  }
  # Use a counting helper to prove failures happen before calling transport.
  actual_request <- runtime$api_request
  calls <- 0L
  runtime$api_request <- function(...) {
    calls <<- calls + 1L
    actual_request(...)
  }
  fails <- function(expr) {
    stopifnot(inherits(tryCatch(force(expr), error = identity), 'error'))
  }
  fails(runtime$json_map(list(a = 'wrong')))
  fails(runtime$json_closed_empty(list(extra = TRUE)))
  fails(runtime$json_mixed(list(id = 1L)))
  fails(runtime$json_mixed(list(id = 'x', extra = 'bad')))
  fails(runtime$json_map(list(a = NULL)))
  fails(runtime$json_closed(list(id = 1L, extra = TRUE)))
  fails(runtime$json_closed(list(note = 'missing id')))
  fails(runtime$json_required())
  fails(runtime$json_required(list()))
  fails(runtime$json_open(NULL))
  fails(runtime$json_array(empty))
  fails(runtime$json_open(list(1L)))
  fails(runtime$json_any(c(1L, 2L)))
  fails(runtime$json_any(list(NA_real_)))
  fails(runtime$json_any(list(Inf)))
  fails(runtime$json_any(data.frame(a = 1)))
  fails(runtime$json_open(setNames(list(1, 2), c('a', 'a'))))
  stopifnot(calls == 0L)
  runtime$api_request <- actual_request
  # Byte-limited JSON uses the other transport serialization branch.
  for (name in c('json_any', 'json_array', 'json_open')) {
    op <- parsed$operations[[name]]
    op$batch <- list(max_bytes = 1000L)
    eval(
      parse(
        text = specmill::render_operation(op, list(helper = 'api_request'))
      ),
      runtime
    )
  }
  stopifnot(
    wire(runtime$json_any(NULL)) == 'null',
    wire(runtime$json_open(list())) == '{}',
    wire(runtime$json_array(list(NULL, empty, list()))) == '[null,{},[]]'
  )
  large <- setNames(as.list(seq_len(10000L)), paste0('key', seq_len(10000L)))
  validate <- getFromNamespace('body_value', 'specmill')
  stopifnot(identical(validate(large, shapes$map), large))
  fixture <- getFromNamespace('body_fixture', 'specmill')
  stopifnot(identical(fixture(shapes$map, large), large))
  fails(fixture(shapes$map, list(a = 'wrong')))
  fails(fixture(shapes$closed, list(id = 1L, extra = TRUE)))
  stopifnot(identical(
    fixture(shapes$any, list(NULL, empty, list())),
    list(NULL, empty, list())
  ))
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
