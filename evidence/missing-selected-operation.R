missing_selected_operation <- function(root) {
  root <- normalizePath(root, winslash = '/', mustWork = TRUE)
  frozen <- readRDS('evidence/baseline/selected-operations.rds')$chemi
  row <- frozen[
    frozen$fn == 'chemi_resolver_ghs_list_count_bulk',
    ,
    drop = FALSE
  ]
  stopifnot(nrow(row) == 1L, row$method == 'POST')
  contracts <- readRDS('evidence/baseline/public-contracts.rds')
  definitions <- unlist(
    lapply(contracts, function(x) {
      vapply(x$definitions, `[[`, character(1), 'name')
    }),
    use.names = FALSE
  )
  stopifnot(
    'chemi_resolver_ghs_list_count' %in% definitions,
    !'chemi_resolver_ghs_list_count_bulk' %in% definitions
  )
  schema <- jsonlite::read_json(file.path(
    root,
    'schema/chemi-resolver-prod.json'
  ))
  route <- schema$paths[['/api/resolver/ghs-list-count']]
  stopifnot(all(c('get', 'post') %in% names(route)))
  exports <- readLines(file.path(root, 'NAMESPACE'), warn = FALSE)
  stopifnot(
    'export(chemi_resolver_ghs_list_count)' %in% exports,
    !'export(chemi_resolver_ghs_list_count_bulk)' %in% exports
  )
  cat(
    'Frozen selection includes POST /api/resolver/ghs-list-count; no frozen definition or current export exists for its selected bulk name. GET remains implemented/exported.\n'
  )
  str(route$post, max.level = 4L)
  invisible(route$post)
}
if (sys.nframe() == 0L) {
  missing_selected_operation(commandArgs(trailingOnly = TRUE)[[1L]])
}
