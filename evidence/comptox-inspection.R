comptox_inspection <- function(root) {
  inspect <- function(path) {
    callbacks <- new.env(parent = baseenv())
    sys.source(file.path(path, 'dev/apipak_callbacks.R'), callbacks)
    apipak::inspect_client(path, callbacks = callbacks)
  }
  original <- inspect(root)
  stage <- readRDS('evidence/staged-client.rds')$root
  candidate <- inspect(stage)
  totals <- function(result, field) sum(vapply(result$coverage, `[[`, numeric(1), field))
  stopifnot(totals(original, 'total') == 343L, totals(original, 'implemented') == 342L,
    totals(candidate, 'total') == 343L, totals(candidate, 'implemented') == 343L,
    totals(candidate, 'contracts') == 343L, !length(candidate$diagnostics),
    all(c('pubchem_search', 'pubchem_properties') %in% names(candidate$manual_exports)))
  saveRDS(list(baseline = original, candidate = candidate), 'evidence/client-inspection.rds')
  cat('Client inspection: baseline 342/343; candidate 343/343 with fixed contracts; manual exports kept outside schema totals.\n')
  invisible(candidate)
}
if (sys.nframe() == 0L) comptox_inspection(commandArgs(trailingOnly = TRUE)[[1L]])
