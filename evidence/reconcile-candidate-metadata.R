# Candidate validation may update reviewed metadata, never bless a runtime diff.
reconcile_candidate_metadata <- function(root) {
  callbacks <- new.env(parent = baseenv())
  sys.source(file.path(root, 'dev/apipak_callbacks.R'), callbacks)
  context <- new.env(parent = asNamespace('apipak'))
  context$apply_files <- function(...) {
    args <- list(...)
    args$mode <- 'plan'
    plan <- do.call(apipak::apply_files, args)
    pending <- Filter(function(x) !x$action %in% c('unchanged', 'retained'), plan)
    stopifnot(all(vapply(pending, function(x) x$file == '.apipak/manifest.json', logical(1))))
    args$mode <- 'apply'
    do.call(apipak::apply_files, args)
  }
  generate <- apipak::generate_client
  environment(generate) <- context
  generate(root, config = 'apipak.yml', callbacks = callbacks, mode = 'apply')
  cat('Candidate metadata reconciled; runtime, documentation and test output unchanged.\n')
}
if (sys.nframe() == 0L) reconcile_candidate_metadata(commandArgs(trailingOnly = TRUE)[[1L]])
