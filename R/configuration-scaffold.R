configuration_words <- function(x) {
  x <- gsub('([A-Z]+)([A-Z][a-z])', '\\1_\\2', x)
  x <- gsub('([a-z0-9])([A-Z])', '\\1_\\2', x)
  x <- tolower(gsub('[^A-Za-z0-9]+', '_', x))
  gsub('^_+|_+$', '', x)
}

configuration_proposal <- function(schema, package, naming, group_by) {
  naming <- match.arg(naming, c('operation_id', 'tag_prefix'))
  group_by <- match.arg(group_by, c('tag', 'none'))
  config_string(package, 'package')
  if (!grepl('^[A-Za-z][A-Za-z0-9.]*$', package) || endsWith(package, '.')) {
    stop('Invalid R package name')
  }
  document <- read_schema_document(schema)
  version <- document$openapi %or% document$swagger
  if (is.null(version) || !grepl('^(3\\.[01]\\.|2\\.0$)', version)) {
    stop('Unsupported schema version')
  }
  if (!is.list(document$paths) || is.null(names(document$paths))) {
    stop('Missing paths')
  }
  records <- list()
  diagnostics <- list()
  report <- function(key, code, message) {
    diagnostics[[length(diagnostics) + 1L]] <<- list(
      key = key,
      code = code,
      message = message
    )
  }
  for (path in sort(names(document$paths), method = 'radix')) {
    item <- tryCatch(
      local_ref(
        document$paths[[path]],
        document,
        source_location = schema_location('#/paths', path)
      ),
      error = identity
    )
    if (inherits(item, 'error')) {
      report(paste('PATH', path), 'unsupported', conditionMessage(item))
      next
    }
    for (method in intersect(
      c('get', 'post', 'put', 'patch', 'delete', 'head', 'options', 'trace'),
      names(item)
    )) {
      key <- paste(toupper(method), path)
      operation <- tryCatch(
        local_ref(
          item[[method]],
          document,
          source_location = schema_location(
            schema_location('#/paths', path),
            method
          )
        ),
        error = identity
      )
      if (inherits(operation, 'error')) {
        report(key, 'unsupported', conditionMessage(operation))
        next
      }
      tags <- operation$tags
      if (
        !is.null(tags) &&
          (!is.list(tags) ||
            !is.null(names(tags)) ||
            !all(vapply(
              tags,
              function(x) {
                is.character(x) &&
                  length(x) == 1L &&
                  !is.na(x)
              },
              logical(1)
            )))
      ) {
        stop('Invalid tags for ', key)
      }
      tags <- Filter(function(tag) nzchar(trimws(tag)), tags)
      tag <- if (length(tags)) tags[[1L]] else 'default'
      if (!length(tags)) {
        report(key, 'missing_tag', 'Assigned to default')
      }
      if (length(tags) > 1L) {
        report(key, 'multiple_tags', paste('Assigned to first tag:', tag))
      }
      group <- configuration_words(tag)
      if (!nzchar(group)) {
        group <- 'group'
      }
      if (
        grepl('^[0-9]|^(con|prn|aux|nul|com[0-9]|lpt[0-9]|api_request)$', group)
      ) {
        group <- paste0('group_', group)
      }
      prefix <- group
      if (group_by == 'none') {
        group <- 'default'
      }
      name <- operation$operationId
      if (
        is.null(name) ||
          !is.character(name) ||
          length(name) != 1L ||
          is.na(name) ||
          !nzchar(name) ||
          !identical(make.names(name), name) ||
          name == '...'
      ) {
        name <- paste(method, configuration_words(path), sep = '_')
        report(key, 'derived_name', paste('Derived name:', name))
      }
      if (naming == 'tag_prefix') {
        words <- strsplit(configuration_words(name), '_', fixed = TRUE)[[1L]]
        # Only exact tag tokens and their simple plural are removed; no synonyms.
        words <- words[!words %in% c(prefix, paste0(prefix, 's'))]
        name <- paste(c(prefix, words), collapse = '_')
      }
      name <- make.names(name)
      records[[length(records) + 1L]] <- list(
        key = key,
        tag = tag,
        group = group,
        name = name
      )
    }
  }
  if (!length(records)) {
    stop('Schema contains no operations')
  }
  keys <- vapply(records, `[[`, character(1), 'key')
  groups <- vapply(records, `[[`, character(1), 'group')
  tags <- vapply(records, `[[`, character(1), 'tag')
  public_names <- vapply(records, `[[`, character(1), 'name')
  members <- split(seq_along(groups), groups)
  for (group in names(members)) {
    if (group_by == 'tag' && length(unique(tags[members[[group]]])) > 1L) {
      report(
        group,
        'group_collision',
        'Distinct tags produce the same service filename'
      )
    }
  }
  collisions <- duplicated(tolower(public_names)) |
    duplicated(tolower(public_names), fromLast = TRUE) |
    public_names %in% c('api_request', 'run_hook')
  for (i in which(collisions)) {
    report(
      keys[[i]],
      'name_collision',
      paste('Review public name:', public_names[[i]])
    )
  }
  # Diagnostic parsing must not fail early on the very name collisions we report.
  parsed <- read_operations(
    schema,
    list(names = as.list(setNames(paste0('operation_', seq_along(keys)), keys)))
  )
  for (diagnostic in parsed$diagnostics) {
    report(diagnostic$key, 'unsupported', diagnostic$reason)
    fields <- c('classification', 'source_location', 'guidance')
    diagnostics[[length(diagnostics)]][fields] <- diagnostic[fields]
    diagnostics[[length(diagnostics)]]$diagnostic_code <- diagnostic$code
  }
  encode <- function(x, comments = list()) {
    text <- sub('\n$', '', yaml::as.yaml(x))
    for (field in names(comments)) {
      text <- sub(
        paste0('(?m)^', field, ':'),
        paste0(comments[[field]], '\n', field, ':'),
        text,
        perl = TRUE
      )
    }
    text
  }
  services <- sort(unique(groups), method = 'radix')
  extension <- tolower(tools::file_ext(schema))
  if (!extension %in% c('yaml', 'yml')) {
    extension <- 'json'
  }
  schema_file <- paste0('schema/openapi.', extension)
  schema_text <- if (
    !is.null(attr(document, 'specmill_reference_dependencies'))
  ) {
    plain <- function(x) {
      if (!is.list(x)) {
        return(x)
      }
      output <- lapply(unclass(x), plain)
      names(output) <- names(x)
      output
    }
    as.character(jsonlite::toJSON(
      plain(document),
      auto_unbox = TRUE,
      pretty = TRUE,
      digits = NA,
      null = 'null'
    ))
  } else {
    file_text(schema)
  }
  files <- setNames(list(schema_text), schema_file)
  project <- list(
    config_version = 1L,
    package = package,
    services = as.list(paste0('apis/', services, '.yml')),
    selection = list(
      methods = as.list(c(
        'GET',
        'POST',
        'PUT',
        'PATCH',
        'DELETE',
        'HEAD',
        'OPTIONS',
        'TRACE'
      )),
      exclude = list()
    ),
    helper = 'api_request',
    documentation = TRUE,
    defaults = list(
      implementation = 'generated',
      batch = list(max_items = NULL, max_bytes = NULL)
    )
  )
  if (
    length(
      document$components$securitySchemes %or% document$securityDefinitions
    ) ||
      !is.null(document$security) ||
      any(vapply(
        parsed$operations,
        function(op) !is.null(op$security),
        logical(1)
      ))
  ) {
    project$authentication <- authentication_envvars(document, package)
  }
  files[['specmill.yml']] <- paste(
    encode(
      project,
      list(
        package = '# Package identity; keep consistent with DESCRIPTION.',
        services = '# Service configuration files, relative to the package root.',
        selection = '# Package-wide limits: services cannot re-enable these excluded methods or paths.',
        helper = '# Default runtime helper; services may override it.',
        documentation = '# Generate help and exports unless a service overrides this setting.',
        defaults = '# Shared settings; service defaults and individual overrides take precedence.\n# Keep function names and output files in service YAML.',
        authentication = paste(
          '# Schema security scheme -> environment variable name. Never put tokens here.',
          '# API keys and bearer tokens are supported; OAuth login/refresh is deferred.',
          sep = '\n'
        )
      )
    ),
    if (is.null(project$authentication)) {
      '# authentication: {} # Opt in to generated auth when the schema declares security.'
    },
    '# Optional formatting: uncomment and use your exact installed air version.',
    '# formatter: {name: air, version: "0.9.0"}',
    '# Callback source files to fingerprint; pass their functions via callbacks, too.',
    'callback_files: []',
    sep = '\n'
  )
  for (group in services) {
    selected <- members[[group]]
    service <- list(
      id = if (group == 'default' && length(services) == 1L) package else group,
      schemas = list(
        files = list(schema_file),
        patterns = list(),
        exclude = list()
      ),
      selection = list(
        methods = as.list(c(
          'GET',
          'POST',
          'PUT',
          'PATCH',
          'DELETE',
          'HEAD',
          'OPTIONS',
          'TRACE'
        )),
        exclude = list(),
        include = as.list(keys[selected])
      ),
      names = as.list(setNames(public_names[selected], keys[selected]))
    )
    # Untagged schemas retain the existing per-function source layout.
    service$defaults <- setNames(list(), character())
    if (group != 'default') {
      service$defaults <- c(
        service$defaults,
        list(
          file = paste0('R/', group, '.R'),
          docs = list(
            tags = list(family = paste(unique(tags[selected]), 'endpoints'))
          )
        )
      )
    }
    service$operations <- setNames(list(), character())
    for (op in parsed$operations) {
      if (
        op$key %in%
          keys[selected] &&
          identical(op$body$type, 'array') &&
          !is.null(op$body$maxItems)
      ) {
        service$operations[[op$key]] <- list(
          batch = list(max_items = op$body$maxItems)
        )
      }
    }
    files[[paste0('apis/', group, '.yml')]] <- paste(
      encode(
        service,
        list(
          schemas = paste(
            '# Local schema files; patterns are file globs, exclude matches basenames by regex.',
            '# All paths resolve from the package root.',
            sep = '\n'
          ),
          selection = paste(
            '# An operation must pass methods AND include AND not match exclude (path regexes).',
            '# Keep only GET and POST below to omit PUT/PATCH/DELETE wrappers.',
            '# Leave their include/name entries in place; regeneration removes unchanged owned output.',
            '# An empty include selects nothing; remove include to allow every matching operation.',
            sep = '\n'
          ),
          helper = '# Runtime request helper, defined in R/.',
          documentation = '# Generate roxygen, help pages, and NAMESPACE exports.',
          names = '# Edit the public R function names here; keys stay METHOD /original/path.',
          defaults = paste(
            '# Shared operation settings. Per-operation settings below override these.',
            '# file groups wrappers in one R file; omit it for one file per function.',
            if (group == 'default') {
              '# Example: add file: R/endpoints.R under defaults.'
            },
            '# docs can set title, description, return, parameters, examples, tags and lifecycle.',
            sep = '\n'
          ),
          operations = paste(
            '# Optional overrides keyed by METHOD /original/path. Replace {} with entries.',
            '# Each entry can set file, helper, parameters, parameter_order and docs.',
            '# parameters keys use the original location and name, e.g. "query limit".',
            '# Example parameter setting: {name: max_results, default: 10, description: Maximum results.}',
            '# Advanced facades use inputs, extra_parameters and request.arguments mappings.',
            sep = '\n'
          )
        )
      ),
      '# Inherited from specmill.yml; uncomment to override for this service:',
      '# helper: api_request',
      '# documentation: true',
      '# Optional hooks: define client functions before enabling these settings.',
      '# hooks: {} # Public wrapper name -> pre_request/post_response hook-name sequences.',
      '# hook_callback: run_hook',
      '# hook_config: inst/hooks.yml # Alternative to inline hooks, not both.',
      '# prepare: prepare_operation # Development callback; pass an explicit callbacks environment.',
      '# policy_version: "1" # Your review label, recorded in generation metadata.',
      '# Optional fixed request expectations for generated tests:',
      '# contracts: {} # Public wrapper name -> fixed request expectations.',
      '# contracts_file: tests/testthat/contracts.rds',
      '# response_fixture: {} # Mock response used by inline single-call contracts.',
      '# Full configuration examples: https://seanthimons.github.io/specmill/articles/configuration.html',
      sep = '\n'
    )
  }
  list(files = files, operations = records, diagnostics = diagnostics)
}

configure_client <- function(
  root,
  schema,
  package = NULL,
  naming = c('operation_id', 'tag_prefix'),
  group_by = c('tag', 'none'),
  mode = c('plan', 'apply')
) {
  mode <- match.arg(mode)
  naming <- match.arg(naming)
  group_by <- match.arg(group_by)
  description <- file.path(root, 'DESCRIPTION')
  if (file.exists(description)) {
    existing <- unname(read.dcf(description)[1L, 'Package'])
    if (!is.null(package) && !identical(package, existing)) {
      stop('Package metadata conflicts with DESCRIPTION')
    }
    package <- existing
  }
  proposal <- if (is.data.frame(schema)) {
    multi_api_proposal(root, schema, package, naming, group_by)
  } else {
    configuration_proposal(schema, package, naming, group_by)
  }
  proposal$changes <- lapply(names(proposal$files), function(file) {
    path <- if (dir.exists(root)) {
      project_path(root, file)
    } else {
      file.path(root, file)
    }
    before <- if (file.exists(path)) file_text(path) else NULL
    list(
      file = file,
      action = if (is.null(before)) {
        'create'
      } else if (identical(before, proposal$files[[file]])) {
        'unchanged'
      } else {
        'conflict'
      },
      before = before,
      after = proposal$files[[file]]
    )
  })
  if (mode == 'apply') {
    conflicts <- vapply(
      Filter(function(x) x$action == 'conflict', proposal$changes),
      `[[`,
      character(1),
      'file'
    )
    if (length(conflicts)) {
      stop(
        'Existing configuration differs; review the plan: ',
        paste(conflicts, collapse = ', ')
      )
    }
    if (
      any(vapply(
        proposal$diagnostics,
        function(x) x$code == 'group_collision',
        logical(1)
      ))
    ) {
      stop('Tag groups collide; review the plan before writing')
    }
    new <- vapply(
      Filter(function(x) x$action == 'create', proposal$changes),
      `[[`,
      character(1),
      'file'
    )
    if (length(new)) {
      dir.create(root, recursive = TRUE, showWarnings = FALSE)
      apply_files(root, proposal$files[new], mode = 'apply')
    }
  }
  proposal
}
