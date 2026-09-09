missing_selected_operation <- function(root, verify_public = FALSE) {
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
  if (verify_public) {
    url <- 'https://hcd.rtpnc.epa.gov/api/resolver/api-docs'
    response <- httr2::request(url) |>
      httr2::req_timeout(20) |>
      httr2::req_perform()
    public <- httr2::resp_body_json(response, simplifyVector = FALSE)
    stopifnot(is.list(public$paths), length(public$paths) > 0L)
    public_route <- public$paths[['/api/resolver/ghs-list-count']]
    canonical <- function(x) {
      if (!is.list(x)) {
        return(x)
      }
      if (!is.null(names(x))) {
        x <- x[sort(names(x))]
      }
      lapply(x, canonical)
    }
    evidence <- list(
      url = url,
      checked_at = format(Sys.time(), tz = 'UTC', usetz = TRUE),
      status = httr2::resp_status(response),
      sha256 = digest::digest(
        httr2::resp_body_raw(response),
        algo = 'sha256',
        serialize = FALSE
      ),
      path = '/api/resolver/ghs-list-count',
      methods = names(public_route),
      post_matches_frozen = identical(
        canonical(public_route$post),
        canonical(route$post)
      )
    )
    print(all.equal(canonical(public_route$post), canonical(route$post)))
    writeBin(
      httr2::resp_body_raw(response),
      'evidence/public-resolver-schema.json'
    )
    jsonlite::write_json(
      evidence,
      'evidence/public-resolver-verification.json',
      auto_unbox = TRUE,
      pretty = TRUE
    )
    print(evidence)
  }
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
  args <- commandArgs(trailingOnly = TRUE)
  missing_selected_operation(
    args[[1L]],
    verify_public = '--verify-public' %in% args
  )
}
