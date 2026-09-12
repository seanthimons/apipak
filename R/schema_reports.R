schema_report_files <- function(
  directory,
  pattern,
  stage_priority,
  exclude_pattern
) {
  files <- list.files(directory, pattern, full.names = FALSE)
  if (!is.null(exclude_pattern)) {
    files <- files[!grepl(exclude_pattern, files, ignore.case = TRUE)]
  }
  if (!is.null(stage_priority)) {
    stage <- sub(
      '^.*-([^-]+)[.](json|ya?ml)$',
      '\\1',
      files,
      ignore.case = TRUE
    )
    group <- sub('-[^-]+[.](json|ya?ml)$', '', files, ignore.case = TRUE)
    ranked <- order(match(stage, stage_priority), files)
    valid <- stage[ranked] %in% stage_priority | stage[ranked] == files[ranked]
    files <- files[ranked][valid & !duplicated(group[ranked])]
  }
  files
}

schema_report_operations <- function(path, policy) {
  if (!file.exists(path)) {
    return(list())
  }
  document <- read_schema_document(path)
  # Diff identities are method/path pairs. Pending facade overrides must not
  # hide new operations or prevent reporting a removed operation.
  keys <- unlist(
    lapply(names(document$paths), function(route) {
      methods <- intersect(
        names(document$paths[[route]]),
        c('get', 'post', 'put', 'patch', 'delete', 'head', 'options', 'trace')
      )
      if (length(methods)) paste(toupper(methods), route) else character()
    }),
    use.names = FALSE
  )
  policy$names <- stats::setNames(
    as.list(paste0('operation_', seq_along(keys))),
    keys
  )
  policy$override_keys <- NULL
  parsed <- read_operations(path, policy)
  canonical <- function(node, references) {
    if (!is.list(node)) {
      return(node)
    }
    if (!is.null(node[['$ref']])) {
      ref <- node[['$ref']]
      if (!exists(ref, references, inherits = FALSE)) {
        assign(ref, NULL, references)
        assign(
          ref,
          canonical(local_ref(node, document), references),
          references
        )
      }
    }
    node <- lapply(node, canonical, references = references)
    if (!is.null(names(node))) {
      node <- node[order(names(node), method = 'radix')]
    }
    node
  }
  selected <- Filter(function(x) x$status != 'excluded', parsed$inventory)
  stats::setNames(
    lapply(selected, function(record) {
      item <- document$paths[[record$path]]
      operation <- item[[tolower(record$method)]]
      references <- new.env(parent = emptyenv())
      contract <- canonical(
        list(
          operation = operation,
          parameters = item$parameters,
          servers = item$servers %or% document$servers,
          security = operation$security %or% document$security,
          host = document$host,
          basePath = document$basePath,
          schemes = document$schemes
        ),
        references
      )
      list(
        route = record$path,
        method = record$method,
        summary = operation$summary %or% '',
        contract = list(
          root = contract,
          references = as.list(references, sorted = TRUE)
        )
      )
    }),
    vapply(selected, `[[`, character(1), 'key')
  )
}

schema_diff <- function(
  old_dir,
  new_dir,
  pattern = '\\.(json|ya?ml)$',
  stage_priority = NULL,
  exclude_pattern = NULL,
  policies = list()
) {
  if (!dir.exists(old_dir) || !dir.exists(new_dir)) {
    stop('Schema comparison directories must exist')
  }
  files <- sort(union(
    schema_report_files(old_dir, pattern, stage_priority, exclude_pattern),
    schema_report_files(new_dir, pattern, stage_priority, exclude_pattern)
  ))
  rows <- function(records) {
    if (!length(records)) {
      return(tibble::tibble(
        route = character(),
        method = character(),
        summary = character()
      ))
    }
    dplyr::bind_rows(lapply(records, function(x) {
      x[c('route', 'method', 'summary')]
    }))
  }
  results <- lapply(files, function(file) {
    policy <- policies[[file]] %or% list()
    old <- schema_report_operations(file.path(old_dir, file), policy)
    new <- schema_report_operations(file.path(new_dir, file), policy)
    common <- intersect(names(old), names(new))
    changed <- common[
      !vapply(
        common,
        function(key) identical(old[[key]]$contract, new[[key]]$contract),
        logical(1)
      )
    ]
    modified <- rows(new[changed])[, c('route', 'method')]
    modified$change_type <- rep('review', length(changed))
    modified$detail <- rep(
      'Schema contract changed; compatibility requires review',
      length(changed)
    )
    modified$breaking <- rep(TRUE, length(changed))
    list(
      schema_file = file,
      added = rows(new[setdiff(names(new), names(old))]),
      removed = rows(old[setdiff(names(old), names(new))]),
      modified = modified
    )
  })
  names(results) <- files
  Filter(
    function(x) nrow(x$added) + nrow(x$removed) + nrow(x$modified) > 0L,
    results
  )
}
