authentication_envvars <- function(document, package) {
  schemes <- document$components$securitySchemes %or%
    document$securityDefinitions %or%
    list()
  ids <- sort(names(schemes), method = 'radix')
  supported <- vapply(
    ids,
    function(id) {
      scheme <- local_ref(schemes[[id]], document)
      identical(scheme$type, 'apiKey') ||
        (identical(scheme$type, 'http') &&
          identical(tolower(scheme$scheme), 'bearer'))
    },
    logical(1)
  )
  ids <- ids[supported]
  if (!length(ids)) {
    return(setNames(list(), character()))
  }
  values <- toupper(paste(
    configuration_words(package),
    vapply(ids, configuration_words, character(1)),
    sep = '_'
  ))
  if (anyDuplicated(values)) {
    stop('Security scheme names produce colliding environment variables')
  }
  as.list(setNames(values, ids))
}

operation_authentication <- function(operation, envvars) {
  requirements <- operation$security %or% list()
  if (!is.list(requirements) || !is.null(names(requirements))) {
    stop('Security must be an array')
  }
  lapply(requirements, function(requirement) {
    if (
      !is.list(requirement) ||
        (length(requirement) && is.null(names(requirement)))
    ) {
      stop('Security requirement must be an object')
    }
    lapply(names(requirement), function(id) {
      scheme <- operation$security_schemes[[id]]
      if (is.null(scheme)) {
        stop('Undefined security scheme: ', id)
      }
      type <- scheme$type
      supported <- identical(type, 'apiKey') ||
        (identical(type, 'http') && identical(tolower(scheme$scheme), 'bearer'))
      if (!supported) {
        return(list(scheme = id, type = type %or% 'unsupported'))
      }
      envvar <- config_string(
        envvars[[id]],
        paste('authentication environment variable for', id)
      )
      if (!grepl('^[A-Za-z_][A-Za-z0-9_]*$', envvar)) {
        stop('Invalid credential environment variable')
      }
      if (length(requirement[[id]])) {
        stop('API key and bearer security requirements cannot declare scopes')
      }
      if (type == 'apiKey') {
        location <- config_string(scheme[['in']], 'API key location')
        if (!location %in% c('header', 'query', 'cookie')) {
          stop('Unsupported API key location')
        }
        name <- config_string(scheme$name, 'API key name')
        if (grepl('[\r\n]', name)) stop('Invalid API key name')
      } else {
        location <- 'header'
        name <- 'Authorization'
      }
      list(
        scheme = id,
        type = if (type == 'http') 'bearer' else type,
        location = location,
        name = name,
        envvar = envvar
      )
    })
  })
}
