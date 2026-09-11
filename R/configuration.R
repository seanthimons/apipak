config_fields <- function(x, allowed, label) {
  if (
    !is.list(x) ||
      inherits(x, 'specmill_sequence') ||
      (length(x) && (is.null(names(x)) || any(!nzchar(names(x)))))
  ) {
    stop(label, ' must be a map')
  }
  unknown <- setdiff(names(x), allowed)
  if (length(unknown)) {
    stop(label, ': unknown field ', paste(unknown, collapse = ', '))
  }
  invisible(x)
}

config_string <- function(x, label) {
  if (!is.character(x) || length(x) != 1L || is.na(x) || !nzchar(x)) {
    stop(label, ' must be a nonempty string')
  }
  x
}

config_sequence <- function(x, label) {
  if (!inherits(x, 'specmill_sequence')) {
    stop(label, ' must be a sequence')
  }
  vapply(x, config_string, character(1), label = label)
}

config_regexes <- function(x, label) {
  patterns <- config_sequence(x, label)
  for (pattern in patterns) {
    tryCatch(stringr::str_detect('', pattern), error = function(e) {
      stop(label, ': invalid regex ', pattern)
    })
  }
  patterns
}

read_config_yaml <- function(path) {
  # The parser handles aliases and duplicate keys; warnings are errors so an
  # executable/unknown tag cannot be silently converted to an ordinary string.
  withCallingHandlers(
    yaml::yaml.load_file(
      path,
      eval.expr = FALSE,
      merge.precedence = 'override',
      handlers = list(
        expr = function(...) stop('Executable YAML tags are forbidden'),
        seq = function(x) structure(x, class = 'specmill_sequence')
      )
    ),
    warning = function(w) stop(conditionMessage(w), call. = FALSE)
  )
}

config_data <- function(x) if (is.list(x)) lapply(x, config_data) else x

read_service_operations <- function(service) {
  parsed <- read_operations(service$files, service[['policy']] %or% list())
  mapped <- character()
  retained <- character()
  known <- vapply(
    c(parsed$operations, parsed$unsupported_operations),
    `[[`,
    character(1),
    'id'
  )
  for (record in parsed$inventory) {
    if (record$status != 'unsupported' || record$id %in% known) {
      next
    }
    settings <- merge_settings(
      service$defaults %or% list(),
      service$operations[[record$key]] %or% list()
    )
    if (!identical(settings$implementation, 'existing')) {
      next
    }
    name <- service[['policy']]$names[[record$key]]
    if (is.null(name)) {
      stop(
        'Retained unsupported operation requires an explicit name: ',
        record$id
      )
    }
    operation <- c(
      record,
      list(
        name = name,
        parameters = list(),
        body = NULL,
        body_required = FALSE,
        summary = name
      )
    )
    configure_operation(operation, service)
    parsed$operations[[name]] <- operation
    retained <- c(retained, record$id)
  }
  for (operation in parsed$unsupported_operations) {
    settings <- merge_settings(
      service$defaults %or% list(),
      service$operations[[operation$key]] %or% list()
    )
    if (!all(c('inputs', 'request') %in% names(settings))) {
      next
    }
    # Complete mappings own the public facade and helper serialization. Schema
    # limitations remain in the inventory; malformed metadata never reaches here.
    configure_operation(operation, service)
    request <- settings$request$arguments
    if (!length(request)) {
      stop('Explicit mapping requires helper arguments: ', operation$id)
    }
    parsed$operations[[operation$name]] <- operation
    if (identical(settings$implementation, 'existing')) {
      retained <- c(retained, operation$id)
    } else {
      mapped <- c(mapped, operation$id)
    }
  }
  parsed$mapping_diagnostics <- Filter(
    function(x) x$id %in% mapped,
    parsed$diagnostics
  )
  parsed$diagnostics <- Filter(
    function(x) !x$id %in% c(mapped, retained),
    parsed$diagnostics
  )
  parsed$retained_diagnostics <- Filter(
    function(x) x$id %in% retained,
    parsed$inventory
  )
  parsed$inventory <- lapply(parsed$inventory, function(x) {
    if (x$id %in% mapped) {
      x$status <- 'client-mapped'
    }
    if (x$id %in% retained) {
      x$status <- 'retained-unsupported'
    }
    x
  })
  parsed
}

load_project <- function(
  root,
  config = 'specmill.yml',
  callbacks = new.env(parent = emptyenv())
) {
  root <- normalizePath(root, winslash = '/', mustWork = TRUE)
  if (!is.environment(callbacks)) {
    stop('callbacks must be an explicit environment')
  }
  project_file <- project_path(root, config_string(config, 'config'))
  project <- read_config_yaml(project_file)
  config_fields(
    project,
    c('config_version', 'services', 'package', 'formatter', 'callback_files'),
    'project'
  )
  if (!is.null(project$formatter)) {
    config_fields(project$formatter, c('name', 'version'), 'formatter')
    if (!identical(project$formatter$name, 'air')) {
      stop('Supported formatter is air')
    }
    config_string(project$formatter$version, 'formatter version')
  }
  if (!identical(project$config_version, 1L)) {
    stop('Unsupported config_version; expected 1')
  }
  service_files <- config_sequence(project$services, 'services')
  if (!length(service_files) || anyDuplicated(service_files)) {
    stop('services must contain distinct service files')
  }
  package <- project$package
  if (is.null(package) && file.exists(file.path(root, 'DESCRIPTION'))) {
    package <- unname(read.dcf(file.path(root, 'DESCRIPTION'))[1L, 'Package'])
  }
  if (!is.null(package)) {
    config_string(package, 'package')
  }
  inputs <- c(project_file)
  if (!is.null(project$callback_files)) {
    callback_files <- config_sequence(project$callback_files, 'callback_files')
    inputs <- c(
      inputs,
      vapply(
        callback_files,
        function(path) project_path(root, path),
        character(1)
      )
    )
    if (!all(file.exists(inputs))) stop('Missing callback input file')
  }
  services <- lapply(service_files, function(file) {
    path <- project_path(root, file)
    service <- read_config_yaml(path)
    inputs <<- c(inputs, path)
    config_fields(
      service,
      c(
        'id',
        'schemas',
        'selection',
        'helper',
        'names',
        'hooks',
        'hook_callback',
        'policy_version',
        'contracts',
        'contracts_file',
        'response_fixture',
        'prepare',
        'documentation',
        'defaults',
        'operations',
        'hook_config'
      ),
      file
    )
    id <- config_string(service$id, paste(file, 'id'))
    config_fields(
      service$schemas,
      c('files', 'patterns', 'exclude'),
      paste(id, 'schemas')
    )
    schema_files <- character()
    if ('files' %in% names(service$schemas)) {
      literal <- config_sequence(service$schemas$files, 'schema files')
      schema_files <- vapply(
        literal,
        function(x) project_path(root, x),
        character(1)
      )
      if (any(!file.exists(schema_files))) stop(id, ': missing schema file')
    }
    if ('patterns' %in% names(service$schemas)) {
      patterns <- config_sequence(service$schemas$patterns, 'schema patterns')
      for (pattern in patterns) {
        matches <- Sys.glob(project_path(root, pattern))
        if (!length(matches)) {
          stop(id, ': schema pattern matched nothing: ', pattern)
        }
        relative <- substring(gsub('\\\\', '/', matches), nchar(root) + 2L)
        schema_files <- c(
          schema_files,
          vapply(relative, function(x) project_path(root, x), character(1))
        )
      }
    }
    if ('exclude' %in% names(service$schemas)) {
      excluded <- config_regexes(service$schemas$exclude, 'schema exclusions')
      for (pattern in excluded) {
        schema_files <- schema_files[
          !stringr::str_detect(basename(schema_files), pattern)
        ]
      }
    }
    schema_files <- sort(unique(schema_files), method = 'radix')
    if (!length(schema_files)) {
      stop(id, ': no schemas selected')
    }
    inputs <<- c(inputs, schema_files)
    selection <- service$selection %or% list()
    config_fields(
      selection,
      c('methods', 'exclude', 'include'),
      paste(id, 'selection')
    )
    include <- if ('include' %in% names(selection)) {
      config_sequence(selection$include, 'operation allowlist')
    } else {
      NULL
    }
    methods <- if ('methods' %in% names(selection)) {
      config_sequence(selection$methods, 'methods')
    } else {
      c('GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'HEAD', 'OPTIONS', 'TRACE')
    }
    if (
      any(
        !methods %in%
          c('GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'HEAD', 'OPTIONS', 'TRACE')
      )
    ) {
      stop(id, ': invalid HTTP method')
    }
    exclude <- if ('exclude' %in% names(selection)) {
      config_regexes(selection$exclude, 'path exclusions')
    } else {
      character()
    }
    helper <- config_string(service$helper, paste(id, 'helper'))
    if (!identical(make.names(helper), helper)) {
      stop(id, ': helper must be an R function name')
    }
    names <- service$names %or% list()
    defaults <- service$defaults %or% list()
    overrides <- service$operations %or% list()
    validate_settings(defaults, paste(id, 'defaults'), callbacks)
    config_fields(overrides, names(overrides), 'operations')
    for (key in names(overrides)) {
      validate_settings(overrides[[key]], key, callbacks)
      if (!is.null(overrides[[key]]$name)) {
        if (
          !is.null(names[[key]]) &&
            !identical(names[[key]], overrides[[key]]$name)
        ) {
          stop('Conflicting name overrides for ', key)
        }
        names[[key]] <- overrides[[key]]$name
      }
    }
    config_fields(names, names(names), paste(id, 'names'))
    for (name in names) {
      if (!identical(make.names(config_string(name, 'wrapper name')), name)) {
        stop('Invalid wrapper name')
      }
    }
    hook_callback <- service$hook_callback %or% 'run_hook'
    config_string(hook_callback, 'hook_callback')
    if (!identical(make.names(hook_callback), hook_callback)) {
      stop('Invalid hook callback name')
    }
    hooks <- service$hooks %or% list()
    if ('hook_config' %in% names(service)) {
      if ('hooks' %in% names(service)) {
        stop('Use hooks or hook_config, not both')
      }
      hook_file <- project_path(
        root,
        config_string(service$hook_config, 'hook_config')
      )
      declarations <- read_config_yaml(hook_file)
      inputs <<- c(inputs, hook_file)
      hooks <- lapply(declarations, function(x) {
        x[intersect(names(x), c('pre_request', 'post_response'))]
      })
      hooks <- Filter(function(x) length(x) > 0L, hooks)
    }
    config_fields(hooks, names(hooks), 'hooks')
    for (hook in hooks) {
      config_fields(hook, c('pre_request', 'post_response'), 'hook stages')
      for (chain in hook) {
        config_sequence(chain, 'hook chain')
      }
    }
    prepare <- NULL
    if (
      'documentation' %in%
        names(service) &&
        (!is.logical(service$documentation) ||
          length(service$documentation) != 1L ||
          is.na(service$documentation))
    ) {
      stop('documentation must be true or false')
    }
    if ('prepare' %in% names(service)) {
      name <- config_string(service$prepare, 'prepare callback')
      if (
        !exists(name, envir = callbacks, mode = 'function', inherits = FALSE)
      ) {
        stop('Unresolved callback: ', name)
      }
      prepare <- get(name, envir = callbacks, inherits = FALSE)
    }
    contracts <- config_data(service[['contracts']]) %or% list()
    config_fields(contracts, names(contracts), 'contracts')
    if (!is.null(service$contracts_file)) {
      relative <- config_string(service$contracts_file, 'contracts_file')
      fixture_path <- project_path(root, relative)
      if (!grepl('^tests/testthat/.+\\.rds$', relative)) {
        stop('contracts_file must be an RDS fixture inside tests/testthat/')
      }
      fixed <- readRDS(fixture_path)
      config_fields(fixed, names(fixed), 'fixed contracts')
      if (length(intersect(names(fixed), names(contracts)))) {
        stop('Duplicate fixed contract')
      }
      for (name in names(fixed)) {
        validate_fixed_contract(fixed[[name]])
      }
      contracts <- c(contracts, fixed)
      inputs <<- c(inputs, fixture_path)
    }
    list(
      id = id,
      files = schema_files,
      helper = helper,
      hooks = hooks,
      hook_config = service$hook_config,
      hook_callback = hook_callback,
      policy = list(
        service = id,
        methods = methods,
        exclude = exclude,
        include = include,
        names = names,
        override_keys = names(overrides)
      ),
      policy_version = service$policy_version %or% '1',
      package = package,
      prepare = prepare,
      callbacks = callbacks,
      documentation = service$documentation,
      defaults = defaults,
      operations = overrides,
      contracts = contracts,
      contracts_file = service$contracts_file,
      response_fixture = config_data(service$response_fixture)
    )
  })
  ids <- vapply(services, `[[`, character(1), 'id')
  if (anyDuplicated(ids)) {
    stop('Duplicate service ID')
  }
  list(
    services = stats::setNames(services, ids),
    inputs = unique(inputs),
    root = root,
    package = package,
    formatter = project$formatter
  )
}
