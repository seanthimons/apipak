parameter_diagnostics_acceptance <- function() {
  file <- tempfile(fileext = '.json')
  on.exit(unlink(file), add = TRUE)
  array <- list(type = 'array', items = list(type = 'integer'))
  cases <- list(
    list(
      p = list(name = 'p', 'in' = 'query', style = 'simple', schema = array),
      code = 'parameter_encoding'
    ),
    list(
      p = list(name = 'p', 'in' = 'header', style = 'form', schema = array),
      code = 'parameter_encoding'
    ),
    list(
      p = list(
        name = 'p',
        'in' = 'query',
        style = 'deepObject',
        explode = FALSE,
        schema = list(type = 'object')
      ),
      code = 'parameter_encoding'
    ),
    list(
      p = list(
        name = 'p',
        'in' = 'query',
        style = 'spaceDelimited',
        schema = list(type = 'string')
      ),
      code = 'parameter_encoding'
    ),
    list(
      p = list(
        name = 'p',
        'in' = 'query',
        schema = list(type = 'object', properties = list(nested = array))
      ),
      code = 'nested_parameter'
    ),
    list(
      p = list(
        name = 'p',
        'in' = 'query',
        schema = list(
          type = 'array',
          items = list(type = 'string', format = 'binary')
        )
      ),
      code = 'binary_parameter'
    ),
    list(
      p = list(
        name = 'p',
        'in' = 'query',
        allowReserved = TRUE,
        schema = list(type = 'string')
      ),
      code = 'parameter_encoding'
    ),
    list(
      p = list(
        name = 'p',
        'in' = 'query',
        schema = list(type = 'array', items = setNames(list(), character()))
      ),
      code = 'parameter_shape'
    ),
    list(
      p = list(
        name = 'p',
        'in' = 'header',
        type = 'array',
        items = list(type = 'integer'),
        collectionFormat = 'multi'
      ),
      version = '2.0',
      code = 'collection_format'
    )
  )
  for (case in cases) {
    document <- list(
      info = list(title = 'Parameters', version = '1'),
      paths = list(
        '/wire' = list(
          get = list(
            operationId = 'wire',
            parameters = list(case$p),
            responses = list('200' = list(description = 'OK'))
          )
        )
      )
    )
    version <- if (is.null(case$version)) '3.0.3' else case$version
    document[[if (version == '2.0') 'swagger' else 'openapi']] <- version
    jsonlite::write_json(document, file, auto_unbox = TRUE)
    result <- specmill::read_operations(file)
    stopifnot(
      !length(result$operations),
      length(result$diagnostics) == 1L,
      result$diagnostics[[1L]]$code == case$code,
      startsWith(
        result$diagnostics[[1L]]$source_location,
        '#/paths/~1wire/get/parameters/0'
      )
    )
  }
  # A newly supported encoding requires a reviewed helper upgrade, never an overwrite.
  document$swagger <- NULL
  document$openapi <- '3.0.3'
  document$paths[['/wire']]$get$parameters <- list(list(
    name = 'p',
    'in' = 'query',
    schema = array
  ))
  jsonlite::write_json(document, file, auto_unbox = TRUE)
  root <- tempfile('parameter-helper-')
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  specmill::initialize_client(
    root,
    file,
    package = 'parameterclient',
    title = 'Parameter Client',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'test@example.org'
    ),
    license = 'MIT + file LICENSE',
    base_url = 'http://127.0.0.1'
  )
  specmill::generate_client(root, config = 'specmill.yml', mode = 'apply')
  helper <- file.path(root, 'R/api_request.R')
  writeLines(
    'api_request <- function(method, path, path_params, query, body) NULL',
    helper
  )
  before <- tools::md5sum(helper)
  error <- tryCatch(
    specmill::generate_client(root, config = 'specmill.yml', mode = 'plan'),
    error = identity
  )
  stopifnot(
    inherits(error, 'error'),
    grepl('parameter_serialization', conditionMessage(error)),
    identical(before, tools::md5sum(helper))
  )
  cat(
    'Parameter diagnostics: invalid/unsupported combinations and client-owned helper migration passed.\n'
  )
}
if (sys.nframe() == 0L) {
  parameter_diagnostics_acceptance()
}
