# Preserve reviewed group policy while consolidating this catalogue-based project.
consolidate_proving_ground_apis <- function(root, backup, apply = FALSE) {
  root <- normalizePath(root, winslash = '/', mustWork = TRUE)
  snapshot <- function() {
    tools::md5sum(list.files(
      root,
      recursive = TRUE,
      all.files = TRUE,
      full.names = TRUE
    ))
  }
  before <- snapshot()
  path <- function(file) {
    getFromNamespace('project_path', 'specmill')(root, file)
  }
  read <- function(file) {
    yaml::yaml.load(
      paste(
        readLines(path(file), encoding = 'UTF-8', warn = FALSE),
        collapse = '\n'
      ),
      handlers = list(seq = function(x) x)
    )
  }
  project <- read('specmill.yml')
  old <- unlist(project$services)
  configs <- lapply(old, read)
  if (all(vapply(configs, function(x) !is.null(x$groups), logical(1)))) {
    return(invisible(list(files = list(), remove = character())))
  }
  stopifnot(all(vapply(configs, function(x) is.null(x$groups), logical(1))))
  catalogue <- Filter(
    function(x) isTRUE(x$include),
    read('specmill-apis.yml')$apis
  )
  assigned <- vapply(
    configs,
    function(config) {
      matches <- Filter(
        function(x) {
          identical(
            unlist(config$schemas$files),
            paste0('schema/', x$api, '.json')
          )
        },
        catalogue
      )
      stopifnot(length(matches) == 1L)
      matches[[1L]]$api
    },
    character(1)
  )
  files <- list()
  for (api in unique(assigned)) {
    groups <- configs[assigned == api]
    ids <- vapply(groups, `[[`, character(1), 'id')
    stopifnot(!anyDuplicated(ids))
    methods <- Reduce(
      union,
      lapply(groups, function(x) unlist(x$selection$methods))
    )
    exclude <- Reduce(
      intersect,
      lapply(groups, function(x) unlist(x$selection$exclude))
    )
    config <- list(api = api)
    shared <- Filter(
      function(field) {
        all(vapply(
          groups,
          function(x) identical(x[[field]], groups[[1L]][[field]]),
          logical(1)
        ))
      },
      c('schemas', 'helper', 'authentication', 'documentation')
    )
    for (field in shared) {
      config[[field]] <- groups[[1L]][[field]]
    }
    config$selection <- list(
      methods = as.list(methods),
      exclude = as.list(exclude)
    )
    config$defaults <- stats::setNames(list(), character())
    config$groups <- stats::setNames(
      lapply(groups, function(group) {
        group$id <- NULL
        group[shared] <- NULL
        group$selection$exclude <- as.list(setdiff(
          unlist(group$selection$exclude),
          exclude
        ))
        group
      }),
      ids
    )
    files[[paste0('apis/', api, '.yml')]] <- getFromNamespace(
      'api_configuration_text',
      'specmill'
    )(config)
  }
  project$services <- as.list(names(files))
  files[['specmill.yml']] <- paste(
    '# Package limits apply to every API and nested endpoint group.',
    sub('\n$', '', yaml::as.yaml(project)),
    sep = '\n'
  )
  remove <- setdiff(old, names(files))
  # Validate resolved semantics in an isolated copy before touching the project.
  stage <- tempfile('api-config-stage-')
  dir.create(stage)
  on.exit(unlink(stage, recursive = TRUE), add = TRUE)
  stopifnot(all(file.copy(
    list.files(root, all.files = TRUE, no.. = TRUE, full.names = TRUE),
    stage,
    recursive = TRUE
  )))
  for (file in names(files)) {
    writeLines(files[[file]], file.path(stage, file))
  }
  unlink(file.path(stage, remove))
  effective <- function(directory) {
    lapply(specmill::load_project(directory)$services, function(x) {
      x$files <- substring(gsub('\\\\', '/', x$files), nchar(directory) + 2L)
      x$callbacks <- NULL
      x$policy <- x$policy[setdiff(
        names(x$policy),
        c('api', 'api_methods', 'api_exclude')
      )]
      x
    })
  }
  stopifnot(identical(
    effective(root),
    effective(normalizePath(stage, winslash = '/'))
  ))
  plan <- specmill::generate_client(
    stage,
    config = 'specmill.yml',
    mode = 'plan'
  )
  if (apply) {
    stopifnot(identical(before, snapshot()))
    stopifnot(!dir.exists(backup))
    dir.create(backup, recursive = TRUE)
    original <- unique(c(old, 'specmill.yml'))
    for (file in original) {
      dir.create(
        dirname(file.path(backup, file)),
        recursive = TRUE,
        showWarnings = FALSE
      )
      stopifnot(file.copy(path(file), file.path(backup, file)))
    }
    stopifnot(
      !any(file.exists(vapply(
        setdiff(names(files), original),
        path,
        character(1)
      )))
    )
    # Only the explicitly validated configuration paths can be replaced or removed.
    tryCatch(
      {
        for (file in names(files)) {
          writeLines(files[[file]], path(file))
        }
        unlink(vapply(remove, path, character(1)))
        stopifnot(identical(
          effective(root),
          effective(normalizePath(stage, winslash = '/'))
        ))
      },
      error = function(e) {
        unlink(vapply(setdiff(names(files), original), path, character(1)))
        for (file in original) {
          file.copy(file.path(backup, file), path(file), overwrite = TRUE)
        }
        stop(e)
      }
    )
  }
  cat(
    length(old),
    'service files ->',
    length(project$services),
    'API files;',
    length(plan$operations),
    'renderable;',
    length(plan$excluded),
    'excluded;',
    length(plan$diagnostics),
    'blocked\n'
  )
  invisible(list(files = files, remove = remove, plan = plan))
}
