render_operation <- function(operation, spec) {
  helper <- spec$helper
  callback <- spec$hook_callback %or% 'run_hook'
  if (operation$name %in% c(helper, callback)) {
    stop('Wrapper name collides with a helper or callback: ', operation$name)
  }
  stopifnot(
    identical(make.names(helper), helper),
    identical(make.names(callback), callback)
  )
  params <- operation$parameters
  input_names <- vapply(params, `[[`, character(1), 'name')
  formal_names <- parameter_names(params)
  formal_names <- make.unique(c(
    formal_names,
    if (!is.null(operation$body)) 'body'
  ))
  mapping <- setNames(
    formal_names[seq_along(input_names)],
    vapply(params, function(p) paste(p$location, p$name), character(1))
  )
  signature <- vapply(
    seq_along(params),
    function(i) {
      paste0(
        formal_names[[i]],
        if (!isTRUE(params[[i]]$public_required %or% params[[i]]$required)) {
          value <- if ('public_default' %in% names(params[[i]])) {
            params[[i]]$public_default
          } else {
            params[[i]]$schema$default
          }
          paste0(' = ', r_literal(value))
        } else {
          ''
        }
      )
    },
    character(1)
  )
  body_name <- if (!is.null(operation$body)) tail(formal_names, 1L) else NULL
  if (!is.null(body_name)) {
    signature <- c(
      signature,
      paste0(body_name, if (!operation$body_required) ' = NULL' else '')
    )
  }
  refs <- function(location) {
    selected <- Filter(function(p) p$location == location, params)
    paste0(
      'list(',
      paste(
        vapply(
          selected,
          function(p) {
            paste0(
              r_literal(p$name),
              ' = params[[',
              r_literal(mapping[[paste(p$location, p$name)]]),
              ']]'
            )
          },
          character(1)
        ),
        collapse = ', '
      ),
      ')'
    )
  }
  lines <- c(
    '# Generated with apipak; do not edit by hand.',
    paste0(
      operation$name,
      ' <- function(',
      paste(signature, collapse = ', '),
      ') {'
    ),
    paste0(
      '  params <- list(',
      paste(
        vapply(
          formal_names,
          function(n) paste0(r_literal(n), ' = ', n),
          character(1)
        ),
        collapse = ', '
      ),
      ')'
    )
  )
  parameter_capture <- tail(lines, 1L)
  lines <- head(lines, -1L)
  for (i in seq_along(params)) {
    if (isTRUE(params[[i]]$missing_as_null)) {
      lines <- c(
        lines,
        paste0(
          '  if (missing(',
          formal_names[[i]],
          ')) ',
          formal_names[[i]],
          ' <- NULL'
        )
      )
    }
    if (
      isTRUE(params[[i]]$public_required %or% params[[i]]$required) &&
        !isTRUE(operation$explicit_inputs)
    ) {
      lines <- c(
        lines,
        paste0(
          '  if (is.null(',
          formal_names[[i]],
          ')) stop(',
          r_literal(paste('Required input:', input_names[[i]])),
          ')'
        )
      )
    }
  }
  if (!is.null(body_name)) {
    if (operation$body_required) {
      lines <- c(
        lines,
        paste0('  if (is.null(', body_name, ')) stop("Required body")')
      )
    }
    checks <- body_checks(operation$body, body_name)
    if (length(checks)) {
      lines <- c(
        lines,
        paste0('  if (!is.null(', body_name, ')) {'),
        paste0('    ', checks),
        '  }'
      )
    }
  }
  lines <- c(lines, parameter_capture)
  hooks <- spec$hooks[[operation$name]] %or% list()
  if (length(hooks$pre_request)) {
    lines <- c(
      lines,
      paste0(
        '  state <- ',
        callback,
        '(',
        r_literal(operation$name),
        ', "pre_request", list(params = params))'
      ),
      if (!isTRUE(spec$post_on_skip)) {
        '  if (isTRUE(state$skip_request)) return(state$result)'
      },
      '  changed <- intersect(names(params), names(state$params))',
      '  params[changed] <- state$params[changed]'
    )
  }
  request <- paste0(
    '  result <- ',
    helper,
    '(method = ',
    r_literal(operation$method),
    ', path = ',
    r_literal(operation$path),
    ', path_params = ',
    refs('path'),
    ', query = ',
    refs('query'),
    ', body = ',
    if (is.null(body_name)) {
      'NULL'
    } else {
      paste0('params[[', r_literal(body_name), ']]')
    },
    ')'
  )
  if (!is.null(spec$request)) {
    arguments <- spec$request$arguments
    request <- paste0(
      '  result <- ',
      helper,
      '(',
      paste(
        vapply(
          names(arguments),
          function(name) {
            paste0(
              r_literal(name),
              ' = ',
              request_binding(
                arguments[[name]],
                formal_names,
                length(hooks$pre_request) > 0L,
                operation,
                spec$callbacks %or% new.env(parent = emptyenv())
              )
            )
          },
          character(1)
        ),
        collapse = ', '
      ),
      ')'
    )
  }
  if (isTRUE(spec$post_on_skip)) {
    if (!length(hooks$pre_request)) {
      stop('post_on_skip requires a pre-request hook')
    }
    request <- c(
      '  if (isTRUE(state$skip_request)) {',
      '    result <- state$result',
      '  } else {',
      paste0('  ', request),
      '  }'
    )
  }
  lines <- c(lines, request)
  if (length(hooks$post_response)) {
    if (identical(spec$post_state, 'hook_state')) {
      if (!length(hooks$pre_request)) {
        stop('post_state hook_state requires a pre-request hook')
      }
      lines <- c(lines, '  state["result"] <- list(result)')
    }
    lines <- c(
      lines,
      paste0(
        '  result <- ',
        callback,
        '(',
        r_literal(operation$name),
        if (identical(spec$post_state, 'hook_state')) {
          ', "post_response", state)'
        } else {
          ', "post_response", list(result = result, params = params))'
        }
      )
    )
  }
  code <- paste(c(lines, '  result', '}'), collapse = '\n')
  if (isTRUE(spec$documentation)) {
    paste(
      operation_documentation(operation, spec$docs %or% list()),
      code,
      sep = '\n'
    )
  } else {
    code
  }
}

generate_client <- function(
  root,
  spec = NULL,
  mode = c('check', 'plan', 'apply'),
  config = NULL,
  callbacks = new.env(parent = emptyenv()),
  adopt = list(),
  artifacts = c('wrappers', 'tests', 'documentation')
) {
  mode <- match.arg(mode)
  if (
    !is.character(artifacts) ||
      !length(artifacts) ||
      anyNA(artifacts) ||
      length(setdiff(artifacts, c('wrappers', 'tests', 'documentation')))
  ) {
    stop('Unknown or empty generation artifacts')
  }
  root <- normalizePath(root, winslash = '/', mustWork = TRUE)
  config_fields(adopt, names(adopt), 'adoption hashes')
  for (name in names(adopt)) {
    config_string(adopt[[name]], 'adoption hash')
    if (
      !grepl('^[0-9a-f]{64}$', adopt[[name]]) ||
        !identical(output_hash(project_path(root, name)), adopt[[name]])
    ) {
      stop('Reviewed adoption hash differs: ', name)
    }
  }
  if (is.null(spec) == is.null(config)) {
    stop('Supply exactly one of spec or config')
  }
  if (!is.null(config)) {
    project <- load_project(root, config, callbacks)
    services <- project$services
    inputs <- project$inputs
    formatter <- project$formatter
  } else {
    if (!is.list(spec)) {
      stop('spec must be a list')
    }
    services <- list(spec)
    inputs <- spec$files
    formatter <- spec$formatter
  }
  # Runtime definitions and documentation are generation inputs too.
  input_directories <- c(
    'R',
    if (
      any(vapply(services, function(x) isTRUE(x$documentation), logical(1)))
    ) {
      c('man', 'data', 'inst')
    }
  )
  runtime_inputs <- function() {
    c(
      unlist(
        lapply(input_directories, function(name) {
          list.files(file.path(root, name), recursive = TRUE, full.names = TRUE)
        }),
        use.names = FALSE
      ),
      file.path(
        root,
        intersect(
          c('DESCRIPTION', 'NAMESPACE', 'LICENSE', 'air.toml', '.air.toml'),
          list.files(root, all.files = TRUE)
        )
      )
    )
  }
  runtime_paths <- runtime_inputs()
  inputs <- unique(c(inputs, runtime_paths))
  input_hash <- function(path) {
    if (
      grepl('\\.(R|Rd|yml|yaml|json|svg|toml)$', path) ||
        basename(path) %in% c('DESCRIPTION', 'NAMESPACE', 'LICENSE', 'WORDLIST')
    ) {
      output_hash(path)
    } else {
      digest::digest(file = path, algo = 'sha256')
    }
  }
  input_hashes <- vapply(
    inputs,
    input_hash,
    character(1)
  )
  callback_hash <- function() {
    digest::digest(
      lapply(as.list(callbacks), function(x) {
        if (is.function(x)) list(deparse(formals(x)), deparse(body(x))) else x
      }),
      algo = 'sha256'
    )
  }
  callbacks_before <- callback_hash()
  drift <- list()
  parsed <- lapply(services, read_service_operations)
  operations <- do.call(c, unname(lapply(parsed, `[[`, 'operations')))
  diagnostics <- do.call(c, unname(lapply(parsed, `[[`, 'diagnostics')))
  inventory <- do.call(c, unname(lapply(parsed, `[[`, 'inventory')))
  operation_names <- vapply(operations, `[[`, character(1), 'name')
  if (anyDuplicated(tolower(operation_names))) {
    stop('Operation names collide across services (including case)')
  }
  reserved <- unlist(
    lapply(services, function(x) c(x$helper, x$hook_callback %or% 'run_hook')),
    use.names = FALSE
  )
  if (any(operation_names %in% reserved)) {
    stop('Wrapper name collides with a helper or callback')
  }
  runtime_definitions <- client_definitions(root)
  if (
    !is.null(config) &&
      any(!reserved %in% c(names(runtime_definitions), 'run_hook'))
  ) {
    stop('Configured helper or callback has no client runtime definition')
  }
  if (mode != 'plan' && length(diagnostics)) {
    stop(
      'Unsupported selected operations; inspect plan diagnostics before generation'
    )
  }
  desired <- list()
  owners <- list()
  configured_operations <- list()
  retained_sources <- character()
  source_names <- list()
  for (i in seq_along(services)) {
    service <- services[[i]]
    renderer <- service$renderer %or% render_operation
    for (op in parsed[[i]]$operations) {
      configured <- configure_operation(op, service)
      op <- configured$operation
      operation_spec <- configured$spec
      if (!is.null(service$prepare)) {
        prepared <- service$prepare(op)
        if (
          !identical(
            prepared[c('id', 'name', 'service', 'key')],
            op[c('id', 'name', 'service', 'key')]
          )
        ) {
          stop(
            'Preparation callback must preserve operation identity and configured name'
          )
        }
        op <- prepared
      }
      configured_operations[[op$name]] <- op
      file <- operation_spec[['file']] %or% paste0('R/', op$name, '.R')
      path <- project_path(root, file)
      if (!grepl('^R/[^/]+\\.R$', file)) {
        stop('Wrapper file must be directly inside R/')
      }
      definition <- runtime_definitions[[op$name]]
      if (!is.null(definition) && !identical(definition$file_path, path)) {
        stop(
          'Wrapper collides with an existing definition in ',
          definition$file_path
        )
      }
      code <- renderer(op, operation_spec)
      if (!is.null(definition)) {
        original_formals <- as.list(formals(eval(definition$expr, baseenv())))
        candidate_formals <- as.list(formals(eval(
          parse(text = code)[[1L]][[3L]],
          baseenv()
        )))
        for (parameter in union(
          names(original_formals),
          names(candidate_formals)
        )) {
          if (
            !identical(
              original_formals[parameter],
              candidate_formals[parameter]
            )
          ) {
            drift[[length(drift) + 1L]] <- list(
              endpoint = op$id,
              parameter = parameter
            )
          }
        }
        if (
          setequal(names(original_formals), names(candidate_formals)) &&
            !identical(names(original_formals), names(candidate_formals))
        ) {
          drift[[length(drift) + 1L]] <- list(
            endpoint = op$id,
            parameter = '<order>'
          )
        }
      }
      if (identical(operation_spec$implementation, 'existing')) {
        if (is.null(definition)) {
          stop('Missing existing implementation: ', op$name)
        }
        candidate <- eval(parse(text = code)[[1L]][[3L]], baseenv())
        original <- eval(definition$expr, baseenv())
        if (!identical(formals(candidate), formals(original))) {
          stop('Existing implementation public contract differs: ', op$name)
        }
        retained_sources <- union(retained_sources, file)
      } else {
        desired[[file]] <- paste(c(desired[[file]], code), collapse = '\n\n')
        owners[[file]] <- c(owners[[file]], op$id)
        source_names[[file]] <- c(source_names[[file]], op$name)
      }
      if (!is.null(config)) {
        helper_definition <- runtime_definitions[[operation_spec$helper]]
        if (is.null(helper_definition)) {
          stop('Missing client helper: ', operation_spec$helper)
        }
        helper_formals <- tg_formal_records(helper_definition$expr)
        required_arguments <- names(Filter(
          function(x) isTRUE(x$required),
          helper_formals
        ))
        sent_arguments <- if (is.null(operation_spec$request)) {
          c('method', 'path', 'path_params', 'query', 'body')
        } else {
          names(operation_spec$request$arguments)
        }
        missing_arguments <- setdiff(required_arguments, sent_arguments)
        if (length(missing_arguments)) {
          stop(
            'Missing required helper arguments for ',
            op$id,
            ': ',
            paste(missing_arguments, collapse = ', ')
          )
        }
        if (
          !'...' %in% names(helper_formals) &&
            length(setdiff(sent_arguments, names(helper_formals)))
        ) {
          stop('Unknown helper arguments for ', op$id)
        }
      }
      if (op$name %in% names(service$contracts)) {
        contract <- service$contracts[[op$name]]
        if (
          !is.null(config) &&
            'calls' %in% names(contract) &&
            length(setdiff(
              vapply(contract$calls, `[[`, character(1), 'helper'),
              names(runtime_definitions)
            ))
        ) {
          stop('Contract references a missing client helper: ', op$name)
        }
        test_file <- paste0(
          'tests/testthat/test-',
          if ('calls' %in% names(contract)) 'contract-',
          op$name,
          '.R'
        )
        desired[[test_file]] <- render_contract(op, operation_spec, contract)
        owners[[test_file]] <- op$id
      }
    }
  }
  if (length(intersect(retained_sources, names(source_names)))) {
    stop('Cannot replace a file containing a retained implementation')
  }
  for (file in names(source_names)) {
    path <- project_path(root, file)
    if (!file.exists(path)) {
      next
    }
    definitions <- tg_find_function_defs_in_file(path)
    expressions <- as.list(parse(path))
    if (
      length(setdiff(names(definitions), source_names[[file]])) ||
        length(expressions) != length(definitions)
    ) {
      stop('Mixed file contains undeclared definitions or other code: ', file)
    }
  }
  attr(desired, 'operations') <- owners
  if (!is.null(formatter)) {
    desired <- format_output(root, desired, formatter)
  }
  labels <- ifelse(
    startsWith(inputs, paste0(root, '/')),
    substring(inputs, nchar(root) + 2L),
    basename(inputs)
  )
  attr(desired, 'inputs') <- as.list(stats::setNames(input_hashes, labels))
  removals <- character()
  renamed <- character()
  manifest_path <- project_path(root, '.apipak/manifest.json')
  if (file.exists(manifest_path)) {
    previous <- jsonlite::read_json(manifest_path)$files
    excluded <- vapply(
      Filter(function(x) x$status == 'excluded', inventory),
      `[[`,
      character(1),
      'id'
    )
    removals <- names(Filter(
      function(x) {
        length(x$operations) && all(unlist(x$operations) %in% excluded)
      },
      previous
    ))
    removals <- setdiff(removals, names(desired))
    # Only an explicit name mapping authorizes moving an existing owned output.
    named_ids <- unlist(
      lapply(seq_along(services), function(i) {
        keys <- names(services[[i]][['policy']]$names)
        vapply(
          Filter(function(op) op$key %in% keys, parsed[[i]]$operations),
          `[[`,
          character(1),
          'id'
        )
      }),
      use.names = FALSE
    )
    relocated <- names(Filter(
      function(x) {
        ids <- unlist(x$operations)
        length(ids) && all(ids %in% named_ids)
      },
      previous
    ))
    relocated <- grep('^(R/|tests/)', relocated, value = TRUE)
    renamed <- setdiff(relocated, c(names(desired), removals))
    # A replacement of the same artifact kind must exist for every old owner.
    renamed <- Filter(
      function(path) {
        prefix <- if (startsWith(path, 'tests/')) {
          'tests/'
        } else if (startsWith(path, 'man/')) {
          'man/'
        } else {
          'R/'
        }
        replacements <- attr(desired, 'operations')[startsWith(
          names(desired),
          prefix
        )]
        all(unlist(previous[[path]]$operations) %in% unlist(replacements))
      },
      renamed
    )
    for (path in renamed) {
      original <- project_path(root, path)
      if (
        file.exists(original) &&
          (!identical(output_hash(original), previous[[path]]$hash) ||
            (endsWith(path, '.R') && has_protected_lifecycle(original)))
      ) {
        stop('Protected original blocks configured rename: ', path)
      }
    }
    removals <- union(removals, renamed)
  }
  if (any(vapply(services, function(x) isTRUE(x$documentation), logical(1)))) {
    desired <- document_output(root, desired, removals)
    if (length(renamed)) {
      old_docs <- setdiff(
        grep('^man/', names(previous), value = TRUE),
        names(desired)
      )
      for (path in old_docs) {
        ids <- unlist(previous[[path]]$operations)
        replacement_ids <- unlist(attr(desired, 'operations')[startsWith(
          names(desired),
          'man/'
        )])
        if (
          length(ids) &&
            all(ids %in% named_ids) &&
            all(ids %in% replacement_ids)
        ) {
          if (
            !identical(
              output_hash(project_path(root, path)),
              previous[[path]]$hash
            )
          ) {
            stop('Protected documentation blocks configured rename: ', path)
          }
          removals <- union(removals, path)
        }
      }
    }
  }
  selected_artifact <- function(paths) {
    kind <- ifelse(
      startsWith(paths, 'R/'),
      'wrappers',
      ifelse(startsWith(paths, 'tests/'), 'tests', 'documentation')
    )
    kind %in% artifacts
  }
  metadata <- attributes(desired)
  desired <- desired[selected_artifact(names(desired))]
  for (name in setdiff(names(metadata), 'names')) {
    attr(desired, name) <- metadata[[name]]
  }
  attr(desired, 'operations') <- attr(desired, 'operations')[names(desired)]
  removals <- removals[selected_artifact(removals)]
  # Record hashes of the resulting source inputs so a second apply is a no-op.
  generated_inputs <- names(desired)[grepl(
    '^(R/|man/|NAMESPACE$)',
    names(desired)
  )]
  attr(desired, 'inputs')[generated_inputs] <- lapply(
    desired[generated_inputs],
    text_hash
  )
  attr(desired, 'inputs') <- attr(desired, 'inputs')[sort(
    setdiff(
      names(attr(desired, 'inputs')),
      removals
    ),
    method = 'radix'
  )]
  attr(desired, 'callbacks') <- callbacks_before
  unused_hooks <- list()
  if (any(vapply(services, function(x) length(x$hooks) > 0L, logical(1)))) {
    wrapper_functions <- lapply(runtime_definitions, function(x) {
      eval(x$expr, baseenv())
    })
    for (name in removals[grepl('^R/.*\\.R$', removals)]) {
      if (!file.exists(project_path(root, name))) {
        next
      }
      removed <- names(tg_find_function_defs_in_file(project_path(root, name)))
      wrapper_functions[removed] <- NULL
    }
    for (name in names(desired)[grepl('\\.R$', names(desired))]) {
      for (expression in as.list(parse(text = desired[[name]]))) {
        if (
          is.call(expression) &&
            identical(expression[[1L]], as.name('<-')) &&
            is.symbol(expression[[2L]]) &&
            is.call(expression[[3L]]) &&
            identical(expression[[3L]][[1L]], as.name('function'))
        ) {
          wrapper_functions[[as.character(expression[[2L]])]] <- eval(
            expression[[3L]],
            baseenv()
          )
        }
      }
    }
    hook_environment <- list2env(wrapper_functions, parent = emptyenv())
    for (service in services) {
      if (!length(service$hooks)) {
        next
      }
      declarations <- service$hooks
      if (!is.null(service$hook_config)) {
        unused_hooks[[service$id]] <- setdiff(
          names(declarations),
          names(wrapper_functions)
        )
        declarations <- declarations[intersect(
          names(declarations),
          names(wrapper_functions)
        )]
      }
      validation <- validate_hooks(
        declarations,
        wrapper_functions,
        hook_environment,
        service$hook_callback %or% 'run_hook'
      )
      if (!validation$valid) stop(paste(validation$errors, collapse = '\n'))
    }
  }
  validate_inputs <- function() {
    if (
      !identical(runtime_paths, runtime_inputs()) ||
        (!is.null(config) &&
          !identical(
            project$inputs,
            load_project(root, config, callbacks)$inputs
          ))
    ) {
      stop('Stale input plan; generation input files changed')
    }
    input_hashes_after <- vapply(inputs, input_hash, character(1))
    if (!identical(input_hashes, input_hashes_after)) {
      stop(
        'Stale input plan; inputs changed during generation: ',
        paste(labels[input_hashes != input_hashes_after], collapse = ', ')
      )
    }
    if (!identical(callbacks_before, callback_hash())) {
      stop('Stale input plan; callback definitions changed during generation')
    }
  }
  validate_inputs()
  # Unsupported operations never remove previous output or manual files.
  result <- apply_files(
    root,
    desired,
    remove = removals,
    mode = mode,
    headers = '# Generated with apipak; do not edit by hand.',
    owned = function(path) {
      relative <- substring(path, nchar(root) + 2L)
      !is.null(adopt[[relative]]) &&
        identical(output_hash(path), adopt[[relative]])
    },
    validate = validate_inputs
  )
  if (
    mode == 'check' &&
      any(vapply(
        result,
        function(x) !x$action %in% c('unchanged', 'retained'),
        logical(1)
      ))
  ) {
    changes <- Filter(
      function(x) !x$action %in% c('unchanged', 'retained'),
      result
    )
    stop(
      'Generated output is stale or protected; inspect plan: ',
      paste(
        vapply(utils::head(changes, 8L), `[[`, character(1), 'file'),
        collapse = ', '
      )
    )
  }
  list(
    files = result,
    operations = configured_operations,
    drift = drift,
    diagnostics = diagnostics,
    mapping_diagnostics = do.call(
      c,
      unname(lapply(parsed, `[[`, 'mapping_diagnostics'))
    ),
    retained_diagnostics = do.call(
      c,
      unname(lapply(parsed, `[[`, 'retained_diagnostics'))
    ),
    unused_hooks = unused_hooks,
    inventory = inventory,
    retained_sources = retained_sources,
    manifest = list(
      toolkit_version = as.character(utils::packageVersion('apipak')),
      inputs = input_hashes,
      policy_version = vapply(
        services,
        function(x) x$policy_version %or% 'unspecified',
        character(1)
      )
    )
  )
}

# Fixed expectations are supplied by the client, independently of wrapper parsing.
check_requests <- function(call, expected, capture, result) {
  actual <- call()
  stopifnot(identical(capture(), expected), identical(actual, result))
  invisible(TRUE)
}
