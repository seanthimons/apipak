# Source this file, then call review_source_contracts(proving_ground).
# Reads snapshots and plans only; never invokes a service operation.
review_source_contracts <- function(root, output = 'dev/audits/source-contracts') {
  historical <- read.csv('dev/audits/proving-ground/operations.csv')
  amos <- historical$api == 'amos' & grepl('invalid_type', historical$findings)
  get_body <- grepl('GET request body', historical$review)
  binary <- grepl('Binary files declared in query', historical$review)
  stopifnot(sum(amos) == 9L, sum(get_body) == 10L, sum(binary) == 11L)
  rows <- historical[amos | get_body | binary, ]
  rows$historical <- TRUE
  previous <- read.csv('dev/audits/composition/active/operations.csv')
  key <- function(x) paste(x$api, x$method, x$path)
  extra <- previous[!key(previous) %in% key(rows), ]
  stopifnot(nrow(extra) == 1L, extra$path == '/api/alerts/groups')
  extra$historical <- FALSE
  rows <- rbind(rows, extra)
  source('dev/audit_proving_ground.R', local = TRUE)
  audit <- audit_proving_ground(root, file.path(output, 'active'))
  stopifnot(
    identical(key(previous), key(audit$diagnostics)),
    length(audit$plan$operations) == 332L,
    length(audit$plan$excluded) == 205L
  )
  excluded <- vapply(audit$plan$excluded, function(x) {
    paste(x$service, x$method, x$path)
  }, character(1))
  parsed_sources <- list()
  ledger <- lapply(seq_len(nrow(rows)), function(i) {
    row <- rows[i, ]
    file <- file.path(root, 'schema', paste0(row$api, '.json'))
    doc <- jsonlite::read_json(file)
    op <- doc$paths[[row$path]][[tolower(row$method)]]
    stopifnot(!is.null(op))
    if (is.null(parsed_sources[[row$api]])) {
      parsed_sources[[row$api]] <- specmill::read_operations(
        file, list(methods = c('GET', 'POST'))
      )
    }
    parsed <- parsed_sources[[row$api]]
    records <- Filter(function(x) x$key == paste(row$method, row$path), parsed$inventory)
    stopifnot(length(records) == 1L)
    record <- records[[1L]]
    group <- if (row$api == 'amos') 'amos' else if (
      grepl('GET request body', row$review)
    ) 'get_body' else 'binary_query'
    review <- switch(group,
      amos = 'Invalid Swagger type; service-owned replacement contract required',
      get_body = 'GET body requires service-owned method, media type and input contract',
      binary_query = 'Binary query requires service-owned field encoding and location'
    )
    data.frame(
      api = row$api, method = row$method, path = row$path,
      historical = row$historical, group = group,
      schema = paste0('schema/', row$api, '.json'),
      sha256 = digest::digest(file = file, algo = 'sha256'),
      pointer = record$source_location,
      disposition = 'unresolved', review_diagnostic = review,
      parser_status = record$status, parser_reason = record$reason,
      active_blocker = key(row) %in% key(audit$diagnostics),
      policy_excluded = paste(row$service, row$method, row$path) %in% excluded,
      evidence = switch(group, amos = 'AMOS.md', get_body = 'GET-BODIES.md',
        binary_query = 'BINARY-QUERY.md'),
      owner = if (group == 'amos' && grepl('/add_', row$path)) '#9' else '#8',
      stringsAsFactors = FALSE
    )
  })
  ledger <- do.call(rbind, ledger)
  stopifnot(!anyDuplicated(key(ledger)), all(nzchar(ledger$review_diagnostic)))
  write.csv(ledger, file.path(output, 'operations.csv'), row.names = FALSE)
  delta <- data.frame(api = character(), method = character(), path = character())
  write.csv(delta, file.path(output, 'changed-operation-keys.csv'), row.names = FALSE)
  write.csv(delta, file.path(output, 'newly-exposed-blockers.csv'), row.names = FALSE)
  print(table(ledger$group, ledger$parser_status))
  cat(nrow(ledger), 'reviewed operations;', sum(ledger$historical), 'historical\n')
  invisible(ledger)
}
