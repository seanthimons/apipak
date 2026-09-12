authentication_acceptance <- function() {
  workspace <- tempfile('authentication-')
  dir.create(workspace)
  on.exit(unlink(workspace, recursive = TRUE), add = TRUE)
  port_file <- file.path(workspace, 'port')
  count_file <- file.path(workspace, 'count')
  server <- callr::r_bg(
    function(port_file, count_file) {
      count <- 0L
      port <- httpuv::randomPort()
      server <- httpuv::startServer(
        '127.0.0.1',
        port,
        list(call = function(req) {
          count <<- count + 1L
          writeLines(as.character(count), count_file)
          list(
            status = 200L,
            headers = list('Content-Type' = 'application/json'),
            body = jsonlite::toJSON(
              list(
                key = req$HTTP_X_API_KEY,
                bearer = req$HTTP_AUTHORIZATION,
                cookie = req$HTTP_COOKIE,
                query = req$QUERY_STRING
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
    list(port_file, count_file),
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
  schemes <- list(
    key = list(type = 'apiKey', name = 'x-api-key', 'in' = 'header'),
    bearer = list(type = 'http', scheme = 'bearer'),
    query = list(type = 'apiKey', name = 'access_key', 'in' = 'query'),
    cookie = list(type = 'apiKey', name = 'session_key', 'in' = 'cookie'),
    oauth = list(type = 'oauth2', flows = list())
  )
  security <- list(
    inherited = NULL,
    public = list(),
    bearer = list(list(bearer = list())),
    query = list(list(query = list())),
    cookie = list(list(cookie = list())),
    either = list(
      list(oauth = list('read')),
      list(key = list()),
      list(bearer = list())
    ),
    both = list(list(key = list(), bearer = list())),
    optional = list(list(key = list()), list()),
    oauth = list(list(oauth = list('read')))
  )
  paths <- lapply(names(security), function(name) {
    op <- list(
      operationId = paste0('get_', name),
      responses = list('200' = list(description = 'OK'))
    )
    if (name != 'inherited') {
      op['security'] <- security[name]
    }
    if (name == 'cookie') {
      op$parameters <- list(list(
        name = 'preference',
        'in' = 'cookie',
        schema = list(type = 'string')
      ))
    }
    if (name == 'query') {
      op$parameters <- list(list(
        name = 'numbers',
        'in' = 'query',
        style = 'form',
        explode = FALSE,
        schema = list(type = 'array', items = list(type = 'string'))
      ))
    }
    list(get = op)
  })
  document <- list(
    openapi = '3.0.3',
    info = list(title = 'Auth', version = '1'),
    security = list(list(key = list())),
    components = list(securitySchemes = schemes),
    paths = setNames(paths, paste0('/', names(security)))
  )
  schema <- file.path(workspace, 'schema.json')
  jsonlite::write_json(document, schema, auto_unbox = TRUE)
  root <- file.path(workspace, 'client')
  specmill::initialize_client(
    root,
    schema,
    package = 'authclient',
    title = 'Auth Client',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'test@example.org'
    ),
    license = 'MIT + file LICENSE',
    base_url = paste0('http://127.0.0.1:', readLines(port_file))
  )
  # The only user configuration is an environment-variable name, never a token.
  project_file <- file.path(root, 'specmill.yml')
  project <- readLines(project_file)
  writeLines(
    sub('AUTHCLIENT_KEY', 'ctx_key', project, fixed = TRUE),
    project_file
  )
  variables <- c(
    'ctx_key',
    'AUTHCLIENT_BEARER',
    'AUTHCLIENT_QUERY',
    'AUTHCLIENT_COOKIE',
    'AUTH_TEST_OTHER'
  )
  withr::local_envvar(setNames(
    rep(NA_character_, length(variables)),
    variables
  ))
  result <- specmill::generate_client(
    root,
    config = 'specmill.yml',
    mode = 'apply'
  )
  stopifnot(
    !length(result$diagnostics),
    file.exists(file.path(root, 'R/api_auth.R')),
    all(
      c('export(api_token)', 'export(set_api_token)') %in%
        readLines(file.path(root, 'NAMESPACE'))
    )
  )
  specmill::generate_client(root, config = 'specmill.yml', mode = 'check')
  runtime <- new.env(parent = baseenv())
  for (file in list.files(file.path(root, 'R'), full.names = TRUE)) {
    sys.source(file, runtime)
  }
  error <- tryCatch(runtime$get_inherited(), error = identity)
  stopifnot(
    inherits(error, 'error'),
    grepl('ctx_key', conditionMessage(error)),
    !file.exists(count_file)
  )
  runtime$set_api_token('fixture-key', scheme = 'key')
  stopifnot(
    runtime$api_token('key') == 'fixture-key',
    runtime$get_inherited()$key == 'fixture-key'
  )
  response <- runtime$get_public()
  stopifnot(is.null(response$key), is.null(response$bearer))
  stopifnot(is.null(runtime$get_optional()$key))
  Sys.unsetenv('ctx_key')
  runtime$set_api_token('fixture-bearer', scheme = 'bearer')
  stopifnot(
    runtime$get_bearer()$bearer == 'Bearer fixture-bearer',
    runtime$get_either()$bearer == 'Bearer fixture-bearer'
  )
  before <- readLines(count_file)
  stopifnot(
    inherits(tryCatch(runtime$get_both(), error = identity), 'error'),
    identical(before, readLines(count_file))
  )
  runtime$set_api_token('fixture-key', scheme = 'key')
  response <- runtime$get_both()
  stopifnot(
    response$key == 'fixture-key',
    response$bearer == 'Bearer fixture-bearer'
  )
  runtime$set_api_token('query/value', scheme = 'query')
  stopifnot(runtime$get_query()$query == '?access_key=query%2Fvalue')
  stopifnot(
    runtime$get_query(numbers = c('a,b', 'c'))$query ==
      '?access_key=query%2Fvalue&numbers=a%2Cb,c'
  )
  runtime$set_api_token('cookie-value', scheme = 'cookie')
  stopifnot(runtime$get_cookie()$cookie == 'session_key=cookie-value')
  stopifnot(
    runtime$get_cookie(preference = 'dark')$cookie ==
      'preference=dark; session_key=cookie-value'
  )
  before <- readLines(count_file)
  error <- tryCatch(runtime$get_oauth(), error = identity)
  stopifnot(
    inherits(error, 'error'),
    grepl('deferred', conditionMessage(error)),
    identical(before, readLines(count_file))
  )
  envfile <- file.path(workspace, '.Renviron')
  writeLines(
    c('# keep this comment', 'AUTH_TEST_OTHER=unchanged', 'ctx_key=old'),
    envfile
  )
  runtime$set_api_token(
    'saved-fixture-key',
    scheme = 'key',
    persist = TRUE,
    file = envfile
  )
  stopifnot(runtime$api_token('key') == 'saved-fixture-key')
  Sys.unsetenv('ctx_key')
  readRenviron(envfile)
  stopifnot(
    runtime$api_token('key') == 'saved-fixture-key',
    Sys.getenv('AUTH_TEST_OTHER') == 'unchanged',
    '# keep this comment' %in% readLines(envfile),
    sum(grepl('^ctx_key=', readLines(envfile))) == 1L
  )
  before <- readLines(envfile)
  for (token in c('', 'line\nbreak', '${HOME}', 'quote"', 'back\\slash')) {
    error <- tryCatch(
      runtime$set_api_token(
        token,
        scheme = 'key',
        persist = TRUE,
        file = envfile
      ),
      error = identity
    )
    stopifnot(inherits(error, 'error'), identical(before, readLines(envfile)))
  }
  # A failed write and failed rollback must retain the recovery copy.
  runtime$file.copy <- function(from, to, ...) {
    if (identical(to, envfile)) {
      return(FALSE)
    }
    base::file.copy(from, to, ...)
  }
  error <- tryCatch(
    runtime$set_api_token(
      'replacement',
      scheme = 'key',
      persist = TRUE,
      file = envfile
    ),
    error = identity
  )
  stopifnot(
    inherits(error, 'error'),
    grepl('recover the backup', conditionMessage(error)),
    length(list.files(
      workspace,
      pattern = '^\\.api-env-backup-',
      all.files = TRUE
    )) ==
      1L,
    identical(before, readLines(envfile))
  )
  rm('file.copy', envir = runtime)
  source <- unlist(lapply(
    list.files(root, recursive = TRUE, full.names = TRUE),
    readLines,
    warn = FALSE
  ))
  stopifnot(!any(grepl('saved-fixture-key|fixture-bearer|query/value', source)))
  # OAuth-only schemas still get a valid empty authentication map and a loud error.
  oauth_document <- document
  oauth_document$components$securitySchemes <- schemes['oauth']
  oauth_document$paths <- document$paths['/oauth']
  oauth_document$security <- list(list(oauth = list('read')))
  jsonlite::write_json(oauth_document, schema, auto_unbox = TRUE)
  oauth_root <- file.path(workspace, 'oauth-client')
  specmill::initialize_client(
    oauth_root,
    schema,
    package = 'oauthclient',
    title = 'OAuth Client',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'test@example.org'
    ),
    license = 'MIT + file LICENSE',
    base_url = 'http://127.0.0.1'
  )
  specmill::generate_client(oauth_root, config = 'specmill.yml', mode = 'apply')
  stopifnot(identical(
    specmill::load_project(oauth_root)$authentication,
    setNames(list(), character())
  ))
  # Changed environment mappings regenerate helpers; edited helpers stay protected.
  cat('\n# user edit\n', file = file.path(root, 'R/api_auth.R'), append = TRUE)
  error <- tryCatch(
    specmill::generate_client(root, config = 'specmill.yml', mode = 'apply'),
    error = identity
  )
  stopifnot(inherits(error, 'error'))
  cat(
    'Authentication: API keys in headers/query/cookies, bearer, inheritance, public overrides, OR/AND, deferred OAuth, missing-token preflight and safe environment persistence passed.\n'
  )
}
if (sys.nframe() == 0L) {
  authentication_acceptance()
}
