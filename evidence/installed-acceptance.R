# Run every installed-package acceptance script in a fresh process.
installed_acceptance <- function(root = '.') {
  root <- normalizePath(root, winslash = '/', mustWork = TRUE)
  scripts <- list.files(file.path(root, 'tests'), '\\.R$', full.names = TRUE)
  results <- lapply(scripts, function(script) {
    log <- file.path(root, 'evidence', paste0('acceptance-', basename(script), '.log'))
    status <- system2(file.path(R.home('bin'), 'Rscript'), shQuote(script), stdout = log, stderr = log)
    cat(basename(script), status, '\n')
    if (status != 0L) stop(paste(readLines(log, warn = FALSE), collapse = '\n'))
    list(script = basename(script), status = status)
  })
  jsonlite::write_json(list(toolkit = as.character(packageVersion('apipak')),
    library = find.package('apipak'), platform = R.version$platform, results = results),
    file.path(root, 'evidence/installed-acceptance.json'), pretty = TRUE, auto_unbox = TRUE)
  invisible(results)
}
if (sys.nframe() == 0L) installed_acceptance()
