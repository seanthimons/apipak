bracket_transport_acceptance <- function() {
  source(
    if (file.exists('tests/native-transport.R')) {
      'tests/native-transport.R'
    } else {
      'native-transport.R'
    },
    local = TRUE
  )
  native_transport_acceptance(function(runtime, root) {
    schema <- tempfile(fileext = '.json')
    config_root <- tempfile('bracket-config-')
    config_schema <- tempfile(fileext = '.json')
    on.exit(unlink(c(schema, config_schema, config_root), recursive = TRUE), add = TRUE)
    parameter <- list(
      name = 'term',
      'in' = 'query',
      required = TRUE,
      schema = list(type = 'array', items = list(type = 'string'))
    )
    document <- list(
      openapi = '3.0.3',
      info = list(title = 'Query arrays', version = '1'),
      paths = list(
        '/search' = list(get = list(
          operationId = 'search',
          parameters = list(parameter),
          responses = list('200' = list(description = 'OK'))
        )),
        '/invalid' = list(get = list(
          operationId = 'invalid',
          parameters = list(modifyList(parameter, list(
            style = 'deepObject',
            schema = list(type = 'array', items = list(type = 'string'))
          ))),
          responses = list('200' = list(description = 'OK'))
        )),
        '/union' = list(get = list(
          operationId = 'union',
          parameters = list(modifyList(parameter, list(schema = list(
            oneOf = list(list(type = 'array', items = list(type = 'string')))
          )))),
          responses = list('200' = list(description = 'OK'))
        ))
      )
    )
    jsonlite::write_json(document, schema, auto_unbox = TRUE, null = 'null')
    standard <- specmill::read_operations(schema)
    stopifnot(
      length(standard$operations) == 1L,
      length(standard$diagnostics) == 2L,
      any(vapply(
        standard$diagnostics,
        function(x) x$key == 'GET /invalid',
        logical(1)
      ))
    )
    parsed <- specmill::read_operations(
      schema,
      list(query_array_style = 'brackets')
    )
    stopifnot(
      identical(parsed$operations$search$parameters[[1L]]$style, 'brackets'),
      identical(parsed$operations$invalid$parameters[[1L]]$style, 'brackets'),
      length(parsed$diagnostics) == 1L,
      identical(parsed$diagnostics[[1L]]$key, 'GET /union')
    )
    eval(
      parse(text = specmill::render_operation(
        parsed$operations$invalid,
        list(helper = 'api_request')
      )),
      runtime
    )
    result <- runtime$invalid(c('red/blue%[]', 'green sky'))
    stopifnot(
      result$query == '?term%5B%5D=red%2Fblue%25%5B%5D&term%5B%5D=green%20sky',
      startsWith(utils::URLdecode(sub('^\\?', '', result$query)), 'term[]=')
    )
    fails <- function(x) {
      stopifnot(inherits(tryCatch(force(x), error = identity), 'error'))
    }
    fails(runtime$invalid())
    fails(runtime$invalid(NULL))
    fails(runtime$invalid(character()))
    fails(runtime$invalid(list(list('nested'))))
    probe <- runtime$api_request('GET', '/probe', list(), list(), NULL)
    stopifnot(probe$request_number == result$request_number + 1L)
    fails(specmill::read_operations(schema, list(query_array_style = 'unknown')))

    legacy <- tempfile(fileext = '.json')
    on.exit(unlink(legacy), add = TRUE)
    jsonlite::write_json(list(
      swagger = '2.0',
      info = list(title = 'Legacy query arrays', version = '1'),
      paths = list('/legacy' = list(get = list(
        operationId = 'legacy',
        parameters = list(list(
          name = 'term',
          'in' = 'query',
          required = TRUE,
          type = 'array',
          items = list(type = 'string'),
          collectionFormat = 'ssv'
        )),
        responses = list('200' = list(description = 'OK'))
      )))
    ), legacy, auto_unbox = TRUE, null = 'null')
    legacy_operation <- specmill::read_operations(
      legacy,
      list(query_array_style = 'brackets')
    )$operations$legacy
    eval(
      parse(text = specmill::render_operation(
        legacy_operation,
        list(helper = 'api_request')
      )),
      runtime
    )
    stopifnot(runtime$legacy(c('red blue', 'green'))$query ==
      '?term%5B%5D=red%20blue&term%5B%5D=green')

    config_document <- document
    config_document$paths <- config_document$paths['/search']
    jsonlite::write_json(
      config_document,
      config_schema,
      auto_unbox = TRUE,
      null = 'null'
    )
    specmill::initialize_client(
      config_root,
      config_schema,
      package = 'bracketclient',
      title = 'Bracket Client',
      author = list(
        given = 'Test',
        family = 'Maintainer',
        email = 'test@example.org'
      ),
      license = 'MIT + file LICENSE',
      base_url = 'http://127.0.0.1'
    )
    config <- file.path(config_root, 'specmill.yml')
    writeLines(
      sub(
        '^defaults:',
        'defaults:\n  query_array_style: brackets',
        readLines(config),
        perl = TRUE
      ),
      config
    )
    plan <- specmill::generate_client(config_root, config = 'specmill.yml', mode = 'plan')
    stopifnot(identical(
      plan$operations$search$parameters[[1L]]$style,
      'brackets'
    ))
    service <- file.path(config_root, 'apis', 'default.yml')
    writeLines(
      sub(
        '^operations: \\{\\}',
        'operations:\n  GET /search:\n    query_array_style: schema',
        readLines(service),
        perl = TRUE
      ),
      service
    )
    plan <- specmill::generate_client(config_root, config = 'specmill.yml', mode = 'plan')
    stopifnot(identical(plan$operations$search$parameters[[1L]]$style, 'form'))
    writeLines(
      sub(
        'query_array_style: schema',
        'query_array_style: brackets',
        readLines(service),
        fixed = TRUE
      ),
      service
    )
    specmill::generate_client(config_root, config = 'specmill.yml', mode = 'apply')
    helper <- file.path(config_root, 'R', 'api_request.R')
    writeLines(
      'api_request <- function(method, path, path_params, query, body) NULL',
      helper
    )
    error <- tryCatch(
      specmill::generate_client(config_root, config = 'specmill.yml', mode = 'plan'),
      error = identity
    )
    stopifnot(
      inherits(error, 'error'),
      grepl('parameter_serialization', conditionMessage(error))
    )
  })
  cat('Bracket query arrays: opt-in wire format, YAML inheritance, validation and helper compatibility passed.\n')
}

if (sys.nframe() == 0L) {
  bracket_transport_acceptance()
}
