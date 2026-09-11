# Copy reviewed selection policy only; do not infer exclusions from diagnostics.
apply_proving_ground_policy <- function(root, comptox_root, apply = FALSE) {
  read <- function(path) {
    yaml::yaml.load(
      paste(readLines(path, encoding = 'UTF-8', warn = FALSE), collapse = '\n'),
      handlers = list(seq = function(x) x)
    )
  }
  project_path <- file.path(root, 'specmill.yml')
  project <- read(project_path)
  catalogue <- Filter(
    function(x) isTRUE(x$include),
    read(file.path(root, 'specmill-apis.yml'))$apis
  )
  changes <- list()
  edit <- function(path, field, value) {
    before <- readLines(path, warn = FALSE)
    section <- which(before == 'selection:')
    stopifnot(length(section) == 1L)
    start <- which(startsWith(before, paste0('  ', field, ':')))
    start <- start[start > section]
    stopifnot(length(start) == 1L)
    boundaries <- which(grepl('^(  [A-Za-z_]+:|[^ #])', before))
    end <- min(c(boundaries[boundaries > start], length(before) + 1L))
    replacement <- strsplit(
      yaml::as.yaml(stats::setNames(list(as.list(value)), field)),
      '\n',
      fixed = TRUE
    )[[1L]]
    after <- append(
      before[-seq.int(start, end - 1L)],
      paste0('  ', replacement),
      after = start - 1L
    )
    expected <- read(path)
    expected$selection[[field]] <- as.list(value)
    actual <- yaml::yaml.load(
      paste(after, collapse = '\n'),
      handlers = list(seq = function(x) x)
    )
    stopifnot(identical(expected, actual))
    if (!identical(before, after)) {
      changes[[path]] <<- list(before = before, after = after)
    }
  }
  edit(project_path, 'methods', c('GET', 'POST'))
  provenance <- lapply(project$services, function(service_file) {
    service_path <- file.path(root, service_file)
    service <- read(service_path)
    match <- Filter(
      function(x) paste0('schema/', x$api, '.json') %in% service$schemas$files,
      catalogue
    )
    stopifnot(length(match) == 1L)
    original <- match[[1L]]$schema
    policy_file <- if (startsWith(original, 'ctx-')) {
      'ctx.yml'
    } else if (original == 'epi-suite-prod.json') {
      'epi.yml'
    } else {
      sub('-prod[.]json$', '.yml', original)
    }
    policy_path <- file.path(comptox_root, 'apis', policy_file)
    policy <- read(policy_path)
    stopifnot(
      paste0('schema/', original) %in% policy$schemas$files,
      setequal(unlist(policy$selection$methods), c('GET', 'POST'))
    )
    patterns <- unique(c(
      unlist(service$selection$exclude),
      unlist(policy$selection$exclude)
    ))
    edit(service_path, 'exclude', patterns)
    data.frame(
      service = service_file,
      api = match[[1L]]$api,
      source_policy = paste0('apis/', policy_file),
      source_sha256 = digest::digest(file = policy_path, algo = 'sha256'),
      exclusions = paste(patterns, collapse = '\n')
    )
  })
  if (apply) {
    # Validate every proposal before writing any of them. Preserve concurrent edits.
    for (path in names(changes)) {
      stopifnot(identical(
        readLines(path, warn = FALSE),
        changes[[path]]$before
      ))
    }
    for (path in names(changes)) {
      writeLines(changes[[path]]$after, path)
    }
  }
  cat(
    length(changes),
    if (apply) {
      'configuration files updated\n'
    } else {
      'configuration files would change\n'
    }
  )
  invisible(list(changes = changes, provenance = do.call(rbind, provenance)))
}
