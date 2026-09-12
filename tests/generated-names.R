generated_names_acceptance <- function() {
  document <- base::list(
    openapi = '3.0.3',
    info = base::list(title = 'Generated names', version = '1'),
    paths = stats::setNames(
      lapply(
        base::c('list', 'c', 'matrix', 'table', 't', 'df'),
        function(name) {
          operation <- base::list(
            operationId = name,
            responses = base::list('200' = base::list(description = 'OK'))
          )
          if (name == 'list') {
            operation$parameters <- base::list(base::list(
              name = 'list',
              `in` = 'query',
              required = TRUE,
              schema = base::list(type = 'string')
            ))
          }
          base::list(get = operation)
        }
      ),
      paste0('/', base::c('list', 'c', 'matrix', 'table', 't', 'df'))
    )
  )
  schema <- tempfile(fileext = '.json')
  root <- tempfile('generated-names-')
  port_file <- tempfile('generated-names-port-')
  on.exit(
    unlink(base::c(schema, root, port_file), recursive = TRUE),
    add = TRUE
  )
  server <- callr::r_bg(
    function(port_file) {
      port <- httpuv::randomPort()
      server <- httpuv::startServer(
        '127.0.0.1',
        port,
        base::list(
          call = function(request) {
            base::list(
              status = 200L,
              headers = base::list('Content-Type' = 'application/json'),
              body = jsonlite::toJSON(
                base::list(
                  path = request$PATH_INFO,
                  query = request$QUERY_STRING
                ),
                auto_unbox = TRUE
              )
            )
          }
        )
      )
      on.exit(server$stop(), add = TRUE)
      writeLines(base::as.character(port), port_file)
      repeat {
        httpuv::service(100)
      }
    },
    base::list(port_file = port_file),
    supervise = TRUE
  )
  on.exit(server$kill(), add = TRUE)
  for (i in base::seq_len(200L)) {
    if (file.exists(port_file)) {
      break
    }
    if (!server$is_alive()) {
      server$get_result()
    }
    Sys.sleep(0.05)
  }
  stopifnot(file.exists(port_file))
  jsonlite::write_json(document, schema, auto_unbox = TRUE)
  specmill::initialize_client(
    root,
    schema,
    package = 'generatednames',
    title = 'Generated names',
    author = base::list(
      given = 'Test',
      family = 'Maintainer',
      email = 'test@example.org'
    ),
    license = 'MIT + file LICENSE',
    base_url = paste0('http://127.0.0.1:', readLines(port_file))
  )
  specmill::generate_client(root, config = 'specmill.yml', mode = 'apply')
  runtime <- new.env(parent = baseenv())
  for (file in list.files(file.path(root, 'R'), full.names = TRUE)) {
    sys.source(file, runtime)
  }
  stopifnot(
    identical(runtime$list(list = 'value')$query, '?list=value'),
    all(vapply(
      base::c('c', 'matrix', 'table', 't', 'df'),
      function(name) {
        identical(runtime[[name]]()$path, paste0('/', name))
      },
      logical(1)
    ))
  )
  body_operation <- base::list(
    name = 'list',
    method = 'POST',
    path = '/list',
    body_required = TRUE,
    body_media = 'application/json',
    body = base::list(type = 'object'),
    parameters = base::list(
      base::list(
        name = 'list',
        location = 'query',
        required = TRUE,
        schema = base::list(type = 'string')
      ),
      base::list(
        name = 'values',
        location = 'query',
        required = FALSE,
        style = 'form',
        explode = TRUE,
        schema = base::list(
          type = 'array',
          items = base::list(type = 'integer'),
          default = base::list(1L, 2L)
        )
      )
    )
  )
  eval(
    parse(
      text = specmill::render_operation(
        body_operation,
        base::list(helper = 'api_request')
      )
    ),
    runtime
  )
  stopifnot(identical(
    runtime$list(list = 'value', body = base::list(extra = 'value'))$query,
    '?list=value&values=1&values=2'
  ))
  runtime$api_request <- function(...) base::list(...)
  operation <- base::list(
    name = 'c',
    method = 'GET',
    path = '/c',
    parameters = base::list(base::list(
      name = 'c',
      location = 'query',
      required = TRUE,
      schema = base::list(type = 'string')
    ))
  )
  code <- specmill::render_operation(
    operation,
    base::list(
      helper = 'api_request',
      request = base::list(
        arguments = base::list(
          values = base::list(
            vector = base::list(
              value = base::list(from = base::list('params', 'c'))
            )
          )
        )
      )
    )
  )
  eval(parse(text = code), runtime)
  stopifnot(identical(runtime$c(c = 'value')$values, base::c(value = 'value')))
  cat(
    'Generated names: base function operation and formal names preserve public calls.\n'
  )
}
if (sys.nframe() == 0L) {
  generated_names_acceptance()
}
