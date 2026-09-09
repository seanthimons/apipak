maintenance_acceptance <- function() {
  root <- tempfile('maintenance-client-')
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  dir.create(file.path(root, 'R'))
  writeLines('export(api_item)', file.path(root, 'NAMESPACE'))
  writeLines(
    'api_item <- function(x) run_hook("api_item", "post_response", x)',
    file.path(root, 'R/item.R')
  )
  policy <- list(forbidden_hosts = 'sandbox[.]example', api_exports = '^api_')
  stopifnot(apipak::check_public_boundary(root, policy, 'api_item'))
  fails <- function(expression, pattern) {
    error <- tryCatch(force(expression), error = identity)
    stopifnot(inherits(error, 'error'), grepl(pattern, conditionMessage(error)))
  }
  fails(
    apipak::check_public_boundary(root, policy, character()),
    'no approved production mapping'
  )
  writeLines('sandbox.example', file.path(root, 'README.md'))
  fails(apipak::check_public_boundary(root, policy), 'Non-production address')
  unlink(file.path(root, 'README.md'))
  policy$forbidden_exports <- '^api_item$'
  fails(apipak::check_public_boundary(root, policy), 'Non-production export')
  hooks <- new.env(parent = baseenv())
  hooks$tidy <- function(x) x
  config <- list(api_item = list(post_response = 'tidy'))
  result <- apipak::check_client_hooks(root, config, hooks)
  stopifnot(result$valid, result$hooks == 1L)
  writeLines('api_item <- function(x) x', file.path(root, 'R/item.R'))
  fails(
    apipak::check_client_hooks(root, config, hooks),
    'does not emit that stage'
  )
  writeLines('api_item <- function(x) x', file.path(root, 'R/duplicate.R'))
  fails(apipak::check_client_hooks(root, config, hooks), 'Duplicate')
  cat(
    'Maintenance: public membership, forbidden artifacts, parsed hook checks and duplicates passed.\n'
  )
}
if (sys.nframe() == 0L) {
  maintenance_acceptance()
}
