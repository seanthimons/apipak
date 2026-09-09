comptox_project_config <- function(root, write = FALSE) {
  root <- normalizePath(root, winslash = '/', mustWork = TRUE)
  mappings <- c(
    readRDS('evidence/interface-probe.rds'),
    readRDS('evidence/chemi-interface-probe.rds')
  )
  mappings <- Filter(function(x) x$status == 'mapped request shape', mappings)
  stopifnot(length(mappings) == 342L)
  docs <- readRDS('evidence/documentation-probe.rds')
  correction <- readRDS('evidence/epi-batch-diagnosis.rds')$settings
  mappings[[
    'epi POST /api/submit/batch'
  ]]$settings$request <- correction$request
  frozen <- readRDS('evidence/baseline/public-contracts.rds')
  by_file <- split(mappings, vapply(mappings, `[[`, character(1), 'file'))
  for (id in names(mappings)) {
    mapping <- mappings[[id]]
    settings <- mapping$settings
    settings$file <- paste0('R/', mapping$file)
    file_definitions <- vapply(
      frozen[[mapping$file]]$definitions,
      `[[`,
      character(1),
      'name'
    )
    declared <- vapply(by_file[[mapping$file]], `[[`, character(1), 'name')
    if (
      mapping$ownership$status != 'selected' ||
        length(setdiff(file_definitions, declared))
    ) {
      settings$implementation <- 'existing'
    }
    if (!identical(settings$implementation, 'existing')) {
      policy <- docs[[id]]
      stopifnot(policy$status == 'mapped documentation')
      settings$docs <- policy$policy
      for (name in names(policy$input_types)) {
        settings$inputs[[name]]$type <- policy$input_types[[name]]
      }
    }
    mappings[[id]]$settings <- settings
  }
  project_file <- yaml::read_yaml(
    file.path(root, 'apipak.yml'),
    eval.expr = FALSE
  )
  output <- list()
  for (relative in project_file$services) {
    path <- file.path(root, relative)
    service <- getFromNamespace('config_data', 'apipak')(getFromNamespace(
      'read_config_yaml',
      'apipak'
    )(path))
    prefix <- paste0(if (service$id == 'ctx') 'ct' else service$id, ' ')
    selected <- mappings[startsWith(names(mappings), prefix)]
    operations <- stats::setNames(
      lapply(selected, `[[`, 'settings'),
      substring(names(selected), nchar(prefix) + 1L)
    )
    extra <- setdiff(names(service$operations), names(operations))
    if (length(extra)) {
      stopifnot(
        service$id == 'chemi-resolver',
        identical(extra, 'POST /api/resolver/ghs-list-count')
      )
      operations[extra] <- service$operations[extra]
    }
    service$operations <- operations
    service$documentation <- TRUE
    output[[relative]] <- yaml::as.yaml(service, precision = 17)
  }
  paths <- file.path(root, names(output))
  hashes <- tools::md5sum(paths)
  if (write) {
    stopifnot(identical(hashes, tools::md5sum(paths)))
    for (relative in names(output)) {
      path <- file.path(root, relative)
      text <- sub('\n$', '', output[[relative]])
      if (!identical(getFromNamespace('file_text', 'apipak')(path), text)) {
        writeLines(enc2utf8(text), path, useBytes = TRUE)
      }
    }
  } else {
    for (relative in names(output)) {
      stopifnot(identical(
        getFromNamespace('file_text', 'apipak')(file.path(root, relative)),
        sub('\n$', '', output[[relative]])
      ))
    }
  }
  callbacks <- new.env(parent = baseenv())
  sys.source(file.path(root, 'dev/apipak_callbacks.R'), callbacks)
  project <- apipak::load_project(root, callbacks = callbacks)
  parsed <- lapply(
    project$services,
    getFromNamespace('read_service_operations', 'apipak')
  )
  operations <- do.call(c, unname(lapply(parsed, `[[`, 'operations')))
  stopifnot(
    length(operations) == 343L,
    !anyDuplicated(vapply(operations, `[[`, character(1), 'name')),
    !length(do.call(c, unname(lapply(parsed, `[[`, 'diagnostics'))))
  )
  inventory <- do.call(c, unname(lapply(parsed, `[[`, 'inventory')))
  print(table(vapply(inventory, `[[`, character(1), 'status')))
  cat(
    'Full client policy: all 343 selected operations remain represented, with explicit retained implementations and schema limitations.\n'
  )
  invisible(project)
}
if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  comptox_project_config(args[[1L]], '--write' %in% args)
}
