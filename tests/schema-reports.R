schema_reports_acceptance <- function() {
  root <- tempfile('schema-reports-')
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  old <- file.path(root, 'old')
  new <- file.path(root, 'new')
  dir.create(old)
  dir.create(new)
  fixture <- jsonlite::read_json(system.file(
    'catalogue/schema.json',
    package = 'apipak'
  ))
  put <- function(value, dir, file = 'sample-prod.json') {
    jsonlite::write_json(value, file.path(dir, file), auto_unbox = TRUE)
  }
  put(fixture, old)
  put(fixture, new)
  stopifnot(!length(apipak::schema_diff(old, new)))
  fixture$components$schemas$Item$properties$related <- list(
    '$ref' = '#/components/schemas/Item'
  )
  put(fixture, old)
  put(fixture, new)
  stopifnot(!length(apipak::schema_diff(old, new)))
  # Key reordering is not contract drift.
  put(fixture[rev(names(fixture))], new)
  stopifnot(!length(apipak::schema_diff(old, new)))
  # A referenced shape change is visible even when the operation's ref is unchanged.
  fixture$components$schemas$Item$properties$title$type <- 'integer'
  put(fixture, new)
  changed <- apipak::schema_diff(old, new)
  stopifnot(
    length(changed) == 1L,
    nrow(changed[[1L]]$modified) > 0L,
    apipak::count_diff_changes(changed)$breaking > 0L,
    grepl('requires review', apipak::format_diff_markdown(changed))
  )
  unlink(file.path(new, 'sample-prod.json'))
  put(fixture, new, 'sample-dev.json')
  removed <- apipak::schema_diff(old, new, stage_priority = 'prod')
  stopifnot(nrow(removed[[1L]]$removed) == 4L, nrow(removed[[1L]]$added) == 0L)
  put(fixture, new, 'new-domain-prod.json')
  added <- apipak::schema_diff(
    old,
    new,
    pattern = '-prod[.]json$',
    stage_priority = 'prod'
  )
  stopifnot(nrow(added[['new-domain-prod.json']]$added) == 4L)
  writeLines('{bad', file.path(new, 'broken-prod.json'))
  error <- tryCatch(apipak::schema_diff(old, new), error = identity)
  stopifnot(inherits(error, 'error'))
  cat(
    'Schema reports: canonical keys, referenced changes, public selection, new domains and blocking parse errors passed.\n'
  )
}
if (sys.nframe() == 0L) {
  schema_reports_acceptance()
}
