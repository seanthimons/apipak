multi_api_proposal <- function(root, apis, package, naming, group_by) {
  required <- c('schema', 'api', 'base_url', 'include')
  if (
    !all(required %in% names(apis)) ||
      !is.logical(apis$include) ||
      anyNA(apis$include)
  ) {
    stop('Supply a reviewed API catalogue')
  }
  apis <- apis[apis$include, , drop = FALSE]
  if (
    !nrow(apis) ||
      anyNA(apis$api) ||
      anyDuplicated(apis$api) ||
      any(!grepl('^[a-z][a-z0-9_]*$', apis$api))
  ) {
    stop('Included APIs require distinct valid names')
  }
  if (
    anyNA(apis$base_url) ||
      any(!grepl('^https?://[^/]+', apis$base_url)) ||
      any(grepl('[{}]', apis$base_url))
  ) {
    stop('Every included API requires an absolute base URL')
  }
  files <- list()
  helpers <- list()
  services <- character()
  authentication <- setNames(list(), character())
  operations <- list()
  diagnostics <- list()
  for (i in seq_len(nrow(apis))) {
    api <- apis$api[[i]]
    schema <- project_path(root, apis$schema[[i]])
    proposal <- configuration_proposal(schema, package, naming, group_by)
    project <- yaml::yaml.load(proposal$files[['specmill.yml']])
    local_auth <- project$authentication
    credentials <- if (length(local_auth)) {
      setNames(
        paste(api, names(local_auth), sep = '.'),
        names(local_auth)
      )
    } else {
      setNames(character(), character())
    }
    for (scheme in names(local_auth)) {
      authentication[[credentials[[scheme]]]] <- toupper(paste(
        configuration_words(package),
        api,
        configuration_words(scheme),
        sep = '_'
      ))
    }
    schema_file <- paste0('schema/', api, '.json')
    files[[schema_file]] <- proposal$files[['schema/openapi.json']]
    helper <- paste0(api, '_request')
    code <- file_text(system.file(
      'templates/request.R',
      package = 'specmill',
      mustWork = TRUE
    ))
    code <- sub('api_request <-', paste0(helper, ' <-'), code, fixed = TRUE)
    helpers[[paste0('R/', helper, '.R')]] <- gsub(
      'BASE_URL',
      r_literal(apis$base_url[[i]]),
      code,
      fixed = TRUE
    )
    api_groups <- list()
    for (file in grep('^apis/', names(proposal$files), value = TRUE)) {
      text <- proposal$files[[file]]
      # Reuse the commented single-schema scaffold, changing only identities.
      text <- gsub('schema/openapi.json', schema_file, text, fixed = TRUE)
      config <- yaml::yaml.load(text, handlers = list(seq = function(x) x))
      id <- paste(api, config$id, sep = '_')
      text <- sub('(?m)^id: [^\n]+', paste0('id: ', id), text, perl = TRUE)
      for (key in names(config$names)) {
        old <- config$names[[key]]
        new <- paste(api, old, sep = '_')
        text <- gsub(
          paste0(': ', old, '\n'),
          paste0(': ', new, '\n'),
          text,
          fixed = TRUE
        )
      }
      if (!is.null(config$defaults$file)) {
        text <- gsub(
          config$defaults$file,
          paste0('R/', id, '.R'),
          text,
          fixed = TRUE
        )
      }
      group <- yaml::yaml.load(text, handlers = list(seq = function(x) x))
      group$id <- NULL
      group$schemas <- NULL
      api_groups[[id]] <- group
    }
    api_config <- list(
      api = api,
      schemas = list(
        files = list(schema_file),
        patterns = list(),
        exclude = list()
      ),
      selection = project$selection,
      helper = helper,
      authentication = as.list(credentials),
      defaults = setNames(list(), character()),
      groups = api_groups
    )
    destination <- paste0('apis/', api, '.yml')
    files[[destination]] <- api_configuration_text(api_config)
    services <- c(services, destination)
    for (op in proposal$operations) {
      op$name <- paste(api, op$name, sep = '_')
      op$api <- api
      operations[[length(operations) + 1L]] <- op
    }
    for (diagnostic in proposal$diagnostics) {
      diagnostic$api <- api
      diagnostics[[length(diagnostics) + 1L]] <- diagnostic
    }
  }
  # Keep project-level comments and defaults from the standard scaffold.
  first_project <- proposal$files[['specmill.yml']]
  root_config <- yaml::yaml.load(
    first_project,
    handlers = list(seq = function(x) x)
  )
  root_config$services <- as.list(services)
  root_config$authentication <- authentication
  files[['specmill.yml']] <- paste(
    '# One API configuration file per schema; endpoint tag groups are nested inside.',
    '# Package-wide settings; API and group filters can only narrow selection.',
    '# Authentication keys are API-name.scheme-name; values are environment variable names.',
    '# Never put tokens here. Share an environment variable only when explicitly intended.',
    sub('\n$', '', yaml::as.yaml(root_config)),
    sep = '\n'
  )
  list(
    files = files,
    helpers = helpers,
    operations = operations,
    diagnostics = diagnostics
  )
}

initialize_apis <- function(
  root,
  apis,
  package,
  title,
  author,
  license,
  naming,
  group_by
) {
  if (file.exists(file.path(root, 'DESCRIPTION'))) {
    stop('Multi-API initialization requires a new package directory')
  }
  proposal <- multi_api_proposal(root, apis, package, naming, group_by)
  first <- apis[apis$include, , drop = FALSE][1L, ]
  stage <- tempfile('multi-api-initialization-')
  on.exit(unlink(stage, recursive = TRUE), add = TRUE)
  initialize_client(
    stage,
    project_path(root, first$schema),
    package,
    title,
    author,
    license,
    first$base_url,
    naming,
    group_by
  )
  metadata <- c('DESCRIPTION', 'NAMESPACE', 'LICENSE', '.Rbuildignore')
  metadata <- metadata[file.exists(file.path(stage, metadata))]
  files <- c(
    proposal$files,
    proposal$helpers,
    setNames(lapply(file.path(stage, metadata), file_text), metadata)
  )
  files[['.Rbuildignore']] <- paste(
    files[['.Rbuildignore']],
    '^specmill-apis\\.yml$',
    '^build\\.R$',
    '^.*\\.json$',
    sep = '\n'
  )
  conflicts <- names(files)[file.exists(file.path(root, names(files)))]
  if (length(conflicts)) {
    stop(
      'Initialization conflicts with existing files: ',
      paste(conflicts, collapse = ', ')
    )
  }
  result <- apply_files(root, files, mode = 'apply')
  attr(result, 'configuration') <- proposal
  result
}
