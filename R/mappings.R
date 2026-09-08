merge_settings <- function(defaults, overrides) {
  for (name in names(overrides)) {
    value <- overrides[[name]]
    if (
      is.list(value) &&
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

validate_settings <- function(settings, label) {
  config_fields(
    settings,
    c(
      'name',
      'helper',
      'parameters',
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
    c('parameters', 'extra_parameters'),
    names(settings)
  )) {
    config_fields(settings[[field]], names(settings[[field]]), field)
    for (parameter in settings[[field]]) {
      config_fields(
        parameter,
        c('name', 'default', 'required', 'exclude', 'description', 'type'),
        'parameter'
      )
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
      config_fields(binding, c('value', 'from'), 'request binding')
      if (length(binding) != 1L) {
        stop('Request binding must contain exactly value or from')
      }
      if ('from' %in% names(binding)) {
        path <- config_sequence(binding$from, 'request reference')
        if (!length(path) || !path[[1L]] %in% c('params', 'hook_state')) {
          stop('Request reference must start with params or hook_state')
        }
      }
    }
  }
  invisible(settings)
}

configure_operation <- function(operation, service) {
  settings <- merge_settings(
    service$defaults %or% list(),
    service$operations[[operation$key]] %or% list()
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
  for (name in names(settings$extra_parameters)) {
    extra <- settings$extra_parameters[[name]]
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
      public_required = isTRUE(extra$required),
      public_default = default,
      required = FALSE,
      schema = list(
        type = extra$type %or% 'string',
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

request_binding <- function(binding, parameters, has_hook) {
  if ('value' %in% names(binding)) {
    return(r_literal(config_data(binding$value)))
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
