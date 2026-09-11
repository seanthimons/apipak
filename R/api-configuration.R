api_configuration_text <- function(config) {
  paste(
    '# One file per API. Tag groups below control naming and R-file layout.',
    '# selection: shared method limits and path exclusions for this API only.',
    '# Package limits still apply; groups can only narrow selection further.',
    '# schemas.exclude filters filenames; selection.exclude filters endpoint paths.',
    '# helper/authentication/defaults are inherited by every group.',
    '# Under groups, edit names and defaults.file; keep excluded include/name entries.',
    '# Group selection.exclude is for additional restrictions, not copies of API policy.',
    '# Group defaults and operation overrides take precedence over API defaults.',
    '# defaults: {} inherits project settings; add batch limits here to override them.',
    '# documentation: true # Optional API override; otherwise inherit the project.',
    '# Never put credential tokens here; authentication values reference project keys.',
    sub('\n$', '', yaml::as.yaml(config)),
    sep = '\n'
  )
}

# Expand API containers into the existing service contract. Flat files are unchanged.
expand_api_configuration <- function(config, file, callbacks) {
  if (!'groups' %in% names(config)) {
    return(list(list(file = file, service = config, api = NULL)))
  }
  config_fields(
    config,
    c(
      'api',
      'schemas',
      'selection',
      'helper',
      'authentication',
      'documentation',
      'defaults',
      'groups'
    ),
    file
  )
  api <- config_string(config$api, paste(file, 'api'))
  if (!grepl('^[a-z][a-z0-9_]*$', api)) {
    stop('Invalid API name: ', api)
  }
  selection <- config$selection %or% list()
  config_fields(selection, c('methods', 'exclude'), paste(api, 'selection'))
  all_methods <- c(
    'GET',
    'POST',
    'PUT',
    'PATCH',
    'DELETE',
    'HEAD',
    'OPTIONS',
    'TRACE'
  )
  methods <- if ('methods' %in% names(selection)) {
    config_sequence(selection$methods, 'API methods')
  } else {
    all_methods
  }
  if (any(!methods %in% all_methods)) {
    stop('Invalid API HTTP method: ', api)
  }
  exclude <- if ('exclude' %in% names(selection)) {
    config_regexes(selection$exclude, 'API path exclusions')
  } else {
    character()
  }
  defaults <- config$defaults %or% list()
  validate_settings(defaults, paste(api, 'defaults'), callbacks)
  if (any(c('name', 'file') %in% names(defaults))) {
    stop('Set name and file in group defaults, not API defaults')
  }
  config_fields(config$groups, names(config$groups), paste(api, 'groups'))
  if (!length(config$groups)) {
    stop('API groups must not be empty: ', api)
  }
  lapply(names(config$groups), function(id) {
    group <- config$groups[[id]]
    config_fields(group, names(group), paste(api, id))
    if (!is.null(group$id) && !identical(group$id, id)) {
      stop('Group ID conflicts with its key: ', id)
    }
    group$id <- id
    for (field in c('schemas', 'helper', 'authentication', 'documentation')) {
      if (!field %in% names(group) && field %in% names(config)) {
        group[[field]] <- config[[field]]
      }
    }
    group$defaults <- merge_settings(defaults, group$defaults %or% list())
    list(
      file = file,
      service = group,
      api = api,
      methods = methods,
      exclude = exclude
    )
  })
}
