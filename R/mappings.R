merge_settings <- function(defaults, overrides) {
  for (name in names(overrides)) {
    value <- overrides[[name]]
    if (
      is.list(value) &&
        !name %in% c('inputs', 'default') &&
        !(length(value) == 1L &&
          names(value) %in%
            c(
              'value',
              'from',
              'object',
              'compact_object',
              'vector',
              'callback'
            )) &&
        !is.null(names(value)) &&
        is.list(defaults[[name]]) &&
        !is.null(names(defaults[[name]]))
    ) {
      defaults[[name]] <- merge_settings(defaults[[name]], value)
    } else {
      defaults[name] <- list(value)
    }
  }
  defaults
}

validate_settings <- function(
  settings,
  label,
  callbacks = new.env(parent = emptyenv())
) {
  config_fields(
    settings,
    c(
      'name',
      'helper',
      'parameters',
      'inputs',
      'extra_parameters',
      'request',
      'post_on_skip',
      'post_state',
      'parameter_order',
      'docs'
    ),
    label
  )
  for (name in intersect(c('name', 'helper', 'post_state'), names(settings))) {
    config_string(settings[[name]], paste(label, name))
  }
  if (
    'post_state' %in%
      names(settings) &&
      !settings$post_state %in% c('parameters', 'hook_state')
  ) {
    stop('post_state must be parameters or hook_state')
  }
  if (
    'post_on_skip' %in%
      names(settings) &&
      (!is.logical(settings$post_on_skip) ||
        length(settings$post_on_skip) != 1L ||
        is.na(settings$post_on_skip))
  ) {
    stop('post_on_skip must be true or false')
  }
  for (field in intersect(
    c('parameters', 'extra_parameters', 'inputs'),
    names(settings)
  )) {
    config_fields(settings[[field]], names(settings[[field]]), field)
    for (parameter in settings[[field]]) {
      config_fields(
        parameter,
        if (field == 'parameters') {
          c('name', 'default', 'required', 'exclude', 'description')
        } else {
          c('default', 'required', 'description', 'type')
        },
        'parameter'
      )
      for (name in intersect(
        names(parameter),
        c('name', 'description', 'type')
      )) {
        config_string(parameter[[name]], paste('parameter', name))
      }
      for (flag in intersect(c('required', 'exclude'), names(parameter))) {
        if (
          !is.logical(parameter[[flag]]) ||
            length(parameter[[flag]]) != 1L ||
            is.na(parameter[[flag]])
        ) {
          stop(flag, ' must be true or false')
        }
      }
    }
  }
  if ('parameter_order' %in% names(settings)) {
    config_sequence(settings$parameter_order, 'parameter_order')
  }
  if ('docs' %in% names(settings)) {
    validate_documentation(settings$docs)
  }
  if ('request' %in% names(settings)) {
    config_fields(settings$request, c('arguments'), 'request')
    config_fields(
      settings$request$arguments,
      names(settings$request$arguments),
      'request arguments'
    )
    for (binding in settings$request$arguments) {
      validate_binding(binding, callbacks)
    }
  }
  invisible(settings)
}

configure_operation <- function(operation, service) {
  settings <- merge_settings(
    service$defaults %or% list(),
    service$operations[[operation$key]] %or% list()
  )
  validate_settings(
    settings,
    operation$id,
    service$callbacks %or% new.env(parent = emptyenv())
  )
  parameters <- operation$parameters
  ids <- vapply(parameters, function(p) paste(p$location, p$name), character(1))
  unknown <- setdiff(names(settings$parameters), ids)
  if (length(unknown)) {
    stop(
      'Unknown parameter override for ',
      operation$id,
      ': ',
      paste(unknown, collapse = ', ')
    )
  }
  keep <- rep(TRUE, length(parameters))
  for (i in seq_along(parameters)) {
    override <- settings$parameters[[ids[[i]]]]
    if (is.null(override)) {
      next
    }
    keep[[i]] <- !isTRUE(override$exclude)
    if ('name' %in% names(override)) {
      parameters[[i]]$public_name <- config_string(
        override$name,
        'public parameter name'
      )
    }
    if ('required' %in% names(override)) {
      parameters[[i]]$public_required <- override$required
    }
    if ('default' %in% names(override)) {
      parameters[[i]]['public_default'] <- list(config_data(override$default))
    }
    if ('description' %in% names(override)) {
      parameters[[i]]$schema$description <- config_string(
        override$description,
        'parameter description'
      )
    }
  }
  parameters <- parameters[keep]
  extra_parameters <- settings$extra_parameters
  if ('inputs' %in% names(settings)) {
    if (
      is.null(settings$request) ||
        length(settings$parameters) ||
        length(extra_parameters)
    ) {
      stop(
        'Explicit inputs require a request mapping and replace parameter overrides/extras'
      )
    }
    operation$schema_parameters <- operation$parameters
    operation$schema_body <- operation$body
    operation$explicit_inputs <- TRUE
    operation$body <- NULL
    operation$body_required <- FALSE
    parameters <- list()
    extra_parameters <- settings$inputs
  }
  for (name in names(extra_parameters)) {
    extra <- extra_parameters[[name]]
    default <- config_data(extra$default)
    if (
      is.list(default) &&
        !is.null(extra$type) &&
        extra$type %in% c('character', 'logical', 'numeric', 'integer')
    ) {
      default <- unlist(default, use.names = FALSE)
    }
    parameters[[length(parameters) + 1L]] <- list(
      name = name,
      location = 'client',
      public_name = name,
      public_required = extra$required %or%
        ('inputs' %in% names(settings) && !'default' %in% names(extra)),
      public_default = default,
      required = FALSE,
      schema = list(
        type = switch(
          extra$type %or% 'string',
          character = 'string',
          numeric = 'number',
          logical = 'boolean',
          extra$type %or% 'string'
        ),
        description = extra$description %or% name
      )
    )
  }
  public_names <- parameter_names(parameters)
  requested_names <- vapply(
    parameters,
    function(p) p$public_name %or% p$name,
    character(1)
  )
  explicit <- vapply(
    parameters,
    function(p) p$public_name %or% '',
    character(1)
  )
  if (
    any(nzchar(explicit) & explicit != public_names) ||
      any(
        nzchar(explicit) &
          requested_names %in% requested_names[duplicated(requested_names)]
      )
  ) {
    stop('Invalid or colliding public parameter name for ', operation$id)
  }
  if (length(settings$parameter_order)) {
    order <- unlist(settings$parameter_order, use.names = FALSE)
    if (any(!order %in% public_names) || anyDuplicated(order)) {
      stop('Invalid public parameter_order for ', operation$id)
    }
    parameters <- parameters[match(
      c(order, setdiff(public_names, order)),
      public_names
    )]
  }
  operation$parameters <- parameters
  spec <- merge_settings(service, settings)
  list(operation = operation, spec = spec)
}

validate_binding <- function(binding, callbacks) {
  config_fields(
    binding,
    c('value', 'from', 'object', 'compact_object', 'vector', 'callback'),
    'request binding'
  )
  if (length(binding) != 1L) {
    stop(
      'Request binding must contain exactly one of value, from, object, compact_object, vector or callback'
    )
  }
  if ('from' %in% names(binding)) {
    path <- config_sequence(binding$from, 'request reference')
    if (!length(path) || !path[[1L]] %in% c('params', 'hook_state')) {
      stop('Request reference must start with params or hook_state')
    }
  }
  for (field in intersect(
    names(binding),
    c('object', 'compact_object', 'vector')
  )) {
    config_fields(
      binding[[field]],
      names(binding[[field]]),
      paste('request', field)
    )
    for (child in binding[[field]]) {
      validate_binding(child, callbacks)
    }
  }
  if ('callback' %in% names(binding)) {
    name <- config_string(binding$callback, 'request callback')
    if (!exists(name, envir = callbacks, mode = 'function', inherits = FALSE)) {
      stop('Unresolved callback: ', name)
    }
  }
  invisible(binding)
}

request_binding <- function(
  binding,
  parameters,
  has_hook,
  operation = NULL,
  callbacks = new.env(parent = emptyenv())
) {
  if ('value' %in% names(binding)) {
    return(r_literal(config_data(binding$value)))
  }
  if ('callback' %in% names(binding)) {
    callback <- get(
      binding$callback,
      envir = callbacks,
      mode = 'function',
      inherits = FALSE
    )
    return(r_literal(callback(operation)))
  }
  for (field in intersect(
    names(binding),
    c('object', 'compact_object', 'vector')
  )) {
    values <- binding[[field]]
    return(paste0(
      if (field == 'vector') {
        'c('
      } else if (field == 'compact_object') {
        'Filter(Negate(is.null), list('
      } else {
        'list('
      },
      paste(
        vapply(
          names(values),
          function(name) {
            paste0(
              r_literal(name),
              ' = ',
              request_binding(
                values[[name]],
                parameters,
                has_hook,
                operation,
                callbacks
              )
            )
          },
          character(1)
        ),
        collapse = ', '
      ),
      if (field == 'compact_object') '))' else ')'
    ))
  }
  path <- unlist(binding$from, use.names = FALSE)
  if (
    path[[1L]] == 'params' && length(path) > 1L && !path[[2L]] %in% parameters
  ) {
    stop('Request references missing public parameter: ', path[[2L]])
  }
  if (path[[1L]] == 'hook_state' && !has_hook) {
    stop('Request references hook_state without a pre-request hook')
  }
  expression <- if (path[[1L]] == 'params') 'params' else 'state'
  for (name in path[-1L]) {
    expression <- paste0(expression, '[[', r_literal(name), ']]')
  }
  expression
}
