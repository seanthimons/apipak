script_root <- function(script) {
  candidates <- c(
    sub('^--file=', '', grep('^--file=', commandArgs(FALSE), value = TRUE)),
    unlist(
      lapply(sys.frames(), function(frame) {
        Filter(is.character, list(frame$ofile, frame$file))
      }),
      use.names = FALSE
    )
  )
  candidates <- candidates[
    basename(candidates) == script & file.exists(candidates)
  ]
  if (!length(candidates)) {
    stop('Cannot locate maintenance script: ', script)
  }
  root <- dirname(normalizePath(
    tail(candidates, 1L),
    winslash = '/',
    mustWork = TRUE
  ))
  while (!file.exists(file.path(root, 'DESCRIPTION'))) {
    parent <- dirname(root)
    if (identical(parent, root)) {
      stop('Maintenance script is outside an R package')
    }
    root <- parent
  }
  root
}

check_public_boundary <- function(root, policy, schema_names = NULL) {
  root <- normalizePath(root, winslash = '/', mustWork = TRUE)
  if (is.character(policy)) {
    policy <- config_data(read_config_yaml(policy))
  }
  config_fields(
    policy,
    c(
      'forbidden_hosts',
      'forbidden_files',
      'forbidden_exports',
      'forbidden_schemas',
      'api_exports',
      'manual_exports'
    ),
    'public boundary policy'
  )
  for (field in setdiff(names(policy), 'manual_exports')) {
    config_string(policy[[field]], field)
    tryCatch(grepl(policy[[field]], '', perl = TRUE), error = function(error) {
      stop('Invalid public boundary pattern: ', field)
    })
  }
  manual <- vapply(
    policy$manual_exports,
    config_string,
    character(1),
    label = 'manual export'
  )
  files <- if (file.exists(file.path(root, '.git'))) {
    paths <- system2(
      'git',
      c(
        '-C',
        shQuote(root),
        'ls-files',
        '--cached',
        '--others',
        '--exclude-standard'
      ),
      stdout = TRUE
    )
    if (!is.null(attr(paths, 'status'))) {
      stop('Cannot inventory public files')
    }
    file.path(root, unique(paths))
  } else {
    list.files(root, recursive = TRUE, full.names = TRUE, all.files = TRUE)
  }
  files <- files[file.exists(files) & !dir.exists(files)]
  text_files <- files[grepl(
    '[.](R|Rd|md|Rmd|json|ya?ml|html|xml|txt|csv|js)$',
    files
  )]
  hits <- if (is.null(policy$forbidden_hosts)) {
    character()
  } else {
    text_files[vapply(
      text_files,
      function(file) {
        any(grepl(
          policy$forbidden_hosts,
          readLines(file, warn = FALSE, encoding = 'UTF-8'),
          ignore.case = TRUE,
          useBytes = TRUE,
          perl = TRUE
        ))
      },
      logical(1)
    )]
  }
  if (length(hits)) {
    stop('Non-production address found: ', paste(hits, collapse = ', '))
  }
  owned <- files[grepl('/(R|man|reference)/', files)]
  if (
    !is.null(policy$forbidden_files) &&
      any(grepl(policy$forbidden_files, basename(owned), perl = TRUE))
  ) {
    stop('Non-production output filename found')
  }
  exports <- tg_parse_namespace_exports(root)
  if (
    !is.null(policy$forbidden_exports) &&
      any(grepl(policy$forbidden_exports, exports, perl = TRUE))
  ) {
    stop('Non-production export found')
  }
  if (!is.null(schema_names)) {
    api <- if (is.null(policy$api_exports)) {
      exports
    } else {
      grep(policy$api_exports, exports, value = TRUE, perl = TRUE)
    }
    missing <- setdiff(api, c(schema_names, manual))
    if (length(missing)) {
      stop(
        'Export has no approved production mapping: ',
        paste(missing, collapse = ', ')
      )
    }
  }
  if (
    !is.null(policy$forbidden_schemas) &&
      length(list.files(file.path(root, 'schema'), policy$forbidden_schemas))
  ) {
    stop('Non-production schema filename found')
  }
  cat(sprintf(
    'Public boundary passed: %d text files scanned.\n',
    length(text_files)
  ))
  invisible(TRUE)
}

check_client_hooks <- function(root, config, hooks, callback = 'run_hook') {
  definitions <- client_definitions(root)
  wrappers <- lapply(definitions, function(definition) {
    eval(definition$expr, envir = hooks)
  })
  result <- validate_hooks(config, wrappers, hooks, callback)
  if (!result$valid) {
    stop(paste(result$errors, collapse = '\n'), call. = FALSE)
  }
  message(sprintf(
    'Hook config validation passed: %d function(s), %d hook(s), %d extra param(s)',
    result$functions,
    result$hooks,
    result$parameters
  ))
  invisible(result)
}

inspect_client <- function(
  root,
  config = 'apipak.yml',
  callbacks = new.env(parent = emptyenv())
) {
  project <- load_project(root, config, callbacks)
  root <- project$root
  definitions <- client_definitions(root)
  exports <- tg_parse_namespace_exports(root)
  operations <- list()
  inventory <- list()
  diagnostics <- list()
  for (service in project$services) {
    parsed <- read_service_operations(service)
    inventory <- c(inventory, parsed$inventory)
    diagnostics <- c(diagnostics, parsed$diagnostics)
    for (operation in parsed$operations) {
      configured <- configure_operation(operation, service)
      name <- operation$name
      definition <- definitions[[name]]
      contract <- service$contracts[[name]]
      test_file <- paste0(
        'tests/testthat/test-',
        if ('calls' %in% names(contract)) 'contract-',
        name,
        '.R'
      )
      operations[[operation$id]] <- list(
        id = operation$id,
        service = service$id,
        method = operation$method,
        path = operation$path,
        name = name,
        implemented = !is.null(definition) && name %in% exports,
        implementation = configured$spec$implementation %or% 'generated',
        file = if (is.null(definition)) {
          NULL
        } else {
          substring(definition$file_path, nchar(root) + 2L)
        },
        contract_declared = !is.null(contract),
        contract_file = if (
          !is.null(contract) && file.exists(file.path(root, test_file))
        ) {
          test_file
        } else {
          NULL
        }
      )
    }
  }
  selected_names <- vapply(operations, `[[`, character(1), 'name')
  if (anyDuplicated(tolower(selected_names))) {
    stop('Operation names collide across services (including case)')
  }
  manual <- setdiff(intersect(exports, names(definitions)), selected_names)
  list(
    operations = operations,
    inventory = inventory,
    diagnostics = diagnostics,
    manual_exports = stats::setNames(
      lapply(manual, function(name) {
        list(
          name = name,
          file = substring(definitions[[name]]$file_path, nchar(root) + 2L)
        )
      }),
      manual
    ),
    coverage = lapply(project$services, function(service) {
      records <- Filter(function(x) x$service == service$id, operations)
      selected <- Filter(
        function(x) x$service == service$id && x$status != 'excluded',
        inventory
      )
      list(
        total = length(selected),
        implemented = sum(vapply(records, `[[`, logical(1), 'implemented')),
        contracts = sum(vapply(
          records,
          function(x) x$contract_declared && !is.null(x$contract_file),
          logical(1)
        ))
      )
    })
  )
}
