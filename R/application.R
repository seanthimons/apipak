# All application and recovery paths use the same containment check.
project_path <- function(root, relative) {
  root <- normalizePath(root, winslash = '/', mustWork = TRUE)
  if (
    !is.character(relative) ||
      length(relative) != 1L ||
      is.na(relative) ||
      !nzchar(relative) ||
      grepl('(^[/\\\\]|:|[\r\n]|(^|[/\\\\])\\.\\.?([/\\\\]|$))', relative)
  ) {
    stop('Unsafe project path: ', relative, call. = FALSE)
  }
  path <- file.path(root, relative)
  ancestor <- path
  while (!identical(ancestor, root)) {
    if (isTRUE(fs::is_link(ancestor))) {
      stop('Symlink in project path: ', relative)
    }
    if (file.exists(ancestor)) {
      resolved <- normalizePath(ancestor, winslash = '/', mustWork = TRUE)
      if (!startsWith(paste0(resolved, '/'), paste0(root, '/'))) {
        stop('Path escapes project root: ', relative)
      }
    }
    ancestor <- dirname(ancestor)
  }
  path
}

file_text <- function(path) {
  paste(readLines(path, warn = FALSE, encoding = 'UTF-8'), collapse = '\n')
}
text_hash <- function(text) {
  digest::digest(
    enc2utf8(gsub('\r\n?', '\n', text)),
    algo = 'sha256',
    serialize = FALSE
  )
}
output_hash <- function(path) {
  if (file.exists(path)) text_hash(file_text(path)) else NULL
}

recovery_journals <- function(root) {
  directories <- list.files(
    root,
    '^\\.(wrapmaint|apipak)-',
    all.files = TRUE,
    full.names = FALSE
  )
  directories[vapply(
    directories,
    function(x) file.exists(project_path(root, paste0(x, '/recovery.rds'))),
    logical(1)
  )]
}

# Recovery validates the entire journal before restoring the first destination.
recover_client <- function(root, mode = c('plan', 'apply')) {
  mode <- match.arg(mode)
  root <- normalizePath(root, winslash = '/', mustWork = TRUE)
  journals <- recovery_journals(root)
  plans <- lapply(journals, function(journal) {
    records <- readRDS(project_path(root, paste0(journal, '/recovery.rds')))
    if (!is.list(records)) {
      stop('Invalid recovery journal: ', journal)
    }
    lapply(records, function(entry) {
      if (
        !is.list(entry) ||
          !is.logical(entry$existed) ||
          length(entry$existed) != 1L ||
          is.na(entry$existed)
      ) {
        stop('Invalid recovery record')
      }
      # Legacy journals used absolute paths. Accept only contained paths.
      relative <- function(path) {
        if (!is.character(path) || length(path) != 1L || is.na(path)) {
          stop('Invalid recovery path')
        }
        path <- gsub('\\\\', '/', path)
        if (startsWith(path, paste0(root, '/'))) {
          substring(path, nchar(root) + 2L)
        } else {
          path
        }
      }
      destination <- project_path(root, relative(entry$path))
      backup <- project_path(root, relative(entry$backup))
      if (!startsWith(backup, paste0(root, '/', journal, '/'))) {
        stop('Backup is outside its recovery journal')
      }
      if (
        entry$existed &&
          (!file.exists(backup) ||
            (!is.null(entry$hash) &&
              !identical(output_hash(backup), entry$hash)))
      ) {
        stop('Missing or changed recovery backup: ', backup)
      }
      list(path = destination, backup = backup, existed = entry$existed)
    })
  })
  if (mode == 'plan') {
    return(stats::setNames(plans, journals))
  }
  lock <- file.path(root, '.apipak-lock')
  if (!dir.create(lock, showWarnings = FALSE)) {
    stop(
      'Project apply lock exists; inspect the interrupted process before recovery'
    )
  }
  on.exit(unlink(lock, recursive = TRUE), add = TRUE)
  for (i in seq_along(plans)) {
    for (entry in plans[[i]]) {
      if (entry$existed) {
        if (
          !file.copy(entry$backup, entry$path, overwrite = TRUE) ||
            !identical(output_hash(entry$backup), output_hash(entry$path))
        ) {
          stop('Recovery failed; journal retained')
        }
      } else if (file.exists(entry$path) && unlink(entry$path) != 0L) {
        stop('Recovery removal failed; journal retained')
      }
    }
    unlink(project_path(root, journals[[i]]), recursive = TRUE)
  }
  invisible(stats::setNames(plans, journals))
}

apply_files <- function(
  root,
  desired,
  remove = character(),
  mode = c('check', 'plan', 'apply'),
  headers = '# Generated with apipak; do not edit by hand.',
  owned = NULL,
  validate = NULL
) {
  mode <- match.arg(mode)
  root <- normalizePath(root, winslash = '/', mustWork = TRUE)
  if (length(recovery_journals(root))) {
    stop(
      'Unresolved recovery journal; use recover_client(root) to review recovery'
    )
  }
  if (
    !is.list(desired) ||
      (length(desired) &&
        (is.null(names(desired)) || any(!nzchar(names(desired))))) ||
      !is.character(remove)
  ) {
    stop('Expected named output text and relative removal paths')
  }
  relatives <- c(names(desired), remove)
  paths <- vapply(
    relatives,
    function(path) project_path(root, path),
    character(1)
  )
  if (anyDuplicated(tolower(as.character(fs::path_norm(paths))))) {
    stop('Output paths collide (including case) or overlap removals')
  }
  manifest_path <- project_path(root, '.apipak/manifest.json')
  if (any(tolower(relatives) == '.apipak/manifest.json')) {
    stop('Manifest is reserved output')
  }
  manifest <- if (file.exists(manifest_path)) {
    jsonlite::read_json(manifest_path, simplifyVector = FALSE)
  } else {
    list(version = 1L, files = list())
  }
  if (
    !identical(as.integer(manifest$version), 1L) || !is.list(manifest$files)
  ) {
    stop('Invalid ownership manifest')
  }
  before <- lapply(paths, output_hash)
  names(before) <- relatives
  manifest_before <- output_hash(manifest_path)
  for (name in names(desired)) {
    if (
      !is.character(desired[[name]]) ||
        length(desired[[name]]) != 1L ||
        is.na(desired[[name]])
    ) {
      stop('Output must be one text string: ', name)
    }
    desired[[name]] <- gsub('\r\n?', '\n', desired[[name]])
    if (grepl('\\.R$', name)) parse(text = desired[[name]])
  }
  adoptable <- logical(length(paths))
  entries <- lapply(seq_along(paths), function(i) {
    path <- paths[[i]]
    name <- relatives[[i]]
    exists <- file.exists(path)
    same <- i <= length(desired) &&
      exists &&
      identical(file_text(path), desired[[name]])
    previous <- manifest$files[[name]]
    verified <- !exists ||
      (!is.null(previous) && identical(before[[i]], previous$hash)) ||
      (is.null(previous) && !is.null(owned) && isTRUE(owned(path)))
    protected <- exists && grepl('\\.R$', name) && has_protected_lifecycle(path)
    adoptable[[i]] <<- verified && !protected
    action <- if (same) {
      'unchanged'
    } else if (!verified || protected) {
      if (i > length(desired)) 'retained' else 'protected'
    } else if (i > length(desired)) {
      if (exists) 'remove' else 'unchanged'
    } else {
      'write'
    }
    list(file = name, path = path, action = action)
  })
  for (entry in entries[adoptable]) {
    if (entry$action == 'remove') {
      manifest$files[[entry$file]] <- NULL
    } else if (entry$file %in% names(desired)) {
      manifest$files[[entry$file]] <- list(
        hash = text_hash(desired[[entry$file]]),
        operations = attr(desired, 'operations')[[entry$file]]
      )
    }
  }
  manifest$files <- manifest$files[sort(
    as.character(names(manifest$files)),
    method = 'radix'
  )]
  # JSON arrays read back as lists; keep one canonical shape across scoped runs.
  manifest$files <- lapply(manifest$files, function(entry) {
    entry$operations <- unlist(entry$operations, use.names = FALSE)
    entry
  })
  manifest$toolkit_version <- as.character(utils::packageVersion('apipak'))
  if (!is.null(attr(desired, 'inputs'))) {
    manifest$inputs <- attr(desired, 'inputs')
  }
  if (!is.null(attr(desired, 'callbacks'))) {
    manifest$callbacks <- attr(desired, 'callbacks')
  }
  if (!is.null(attr(desired, 'formatter'))) {
    manifest$formatter <- attr(desired, 'formatter')
  }
  desired[['.apipak/manifest.json']] <- as.character(jsonlite::toJSON(
    manifest,
    auto_unbox = TRUE,
    pretty = TRUE,
    null = 'null'
  ))
  manifest_changed <- (length(manifest$files) > 0L ||
    !is.null(manifest_before)) &&
    !identical(manifest_before, text_hash(desired[['.apipak/manifest.json']]))
  if (manifest_changed) {
    entries <- c(
      entries,
      list(list(
        file = '.apipak/manifest.json',
        path = manifest_path,
        action = 'write'
      ))
    )
  }
  if (mode != 'apply') {
    return(entries)
  }
  if (any(vapply(entries, function(e) e$action == 'protected', logical(1)))) {
    stop('Protected output conflicts; no files applied')
  }
  pending <- Filter(function(e) e$action %in% c('write', 'remove'), entries)
  if (!length(pending)) {
    return(entries)
  }
  lock <- file.path(root, '.apipak-lock')
  if (!dir.create(lock, showWarnings = FALSE)) {
    stop('Another apply holds the project lock')
  }
  on.exit(unlink(lock, recursive = TRUE), add = TRUE)
  if (!is.null(validate)) {
    validate()
  }
  if (
    !identical(
      before,
      stats::setNames(lapply(paths, output_hash), relatives)
    ) ||
      !identical(manifest_before, output_hash(manifest_path))
  ) {
    stop('Stale output plan; project changed during planning')
  }
  transaction <- tempfile('.apipak-', tmpdir = root)
  if (!dir.create(transaction)) {
    stop('Cannot stage output')
  }
  backup <- list()
  complete <- FALSE
  on.exit(
    {
      if (!complete && length(backup)) {
        restored <- vapply(
          backup,
          function(entry) {
            if (entry$existed) {
              file.copy(entry$backup, entry$path, overwrite = TRUE) &&
                identical(output_hash(entry$path), entry$hash)
            } else {
              !file.exists(entry$path) || unlink(entry$path) == 0L
            }
          },
          logical(1)
        )
        if (!all(restored)) {
          warning('Rollback failed; recovery journal retained')
        }
      }
      if (complete) unlink(transaction, recursive = TRUE)
    },
    add = TRUE
  )
  for (i in seq_along(pending)) {
    entry <- pending[[i]]
    copy <- file.path(transaction, paste0(i, '.backup'))
    existed <- file.exists(entry$path)
    if (existed && !file.copy(entry$path, copy)) {
      stop('Cannot back up output')
    }
    backup[[i]] <- list(
      path = entry$path,
      existed = existed,
      backup = copy,
      hash = output_hash(entry$path)
    )
    if (entry$action == 'write') {
      writeLines(
        enc2utf8(desired[[entry$file]]),
        file.path(transaction, paste0(i, '.new')),
        useBytes = TRUE
      )
    }
  }
  saveRDS(backup, file.path(transaction, 'recovery.rds'))
  for (i in seq_along(pending)) {
    entry <- pending[[i]]
    # Revalidate containment immediately before touching each destination.
    project_path(root, entry$file)
    if (entry$action == 'remove') {
      if (unlink(entry$path) != 0L) stop('Cannot remove output')
    } else {
      dir.create(dirname(entry$path), recursive = TRUE, showWarnings = FALSE)
      if (
        !file.copy(
          file.path(transaction, paste0(i, '.new')),
          entry$path,
          overwrite = TRUE
        ) ||
          !identical(output_hash(entry$path), text_hash(desired[[entry$file]]))
      ) {
        stop('Cannot verify applied output')
      }
    }
  }
  complete <- TRUE
  entries
}
