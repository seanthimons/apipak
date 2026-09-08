loading_acceptance <- function() {
  directory <- tempfile('empty-working-directory-')
  dir.create(directory)
  old <- setwd(directory)
  on.exit(setwd(old), add = TRUE)
  # Load declared dependencies first, so dependency startup is not confused
  # with toolkit startup. The toolkit must add no client or process policy.
  for (package in c(
    'cli',
    'dplyr',
    'fs',
    'jsonlite',
    'purrr',
    'readr',
    'stringr',
    'tibble',
    'tidyr'
  )) {
    requireNamespace(package, quietly = TRUE)
  }
  previous_options <- options()
  previous_search <- search()
  requireNamespace('apipak', quietly = TRUE)
  stopifnot(
    identical(previous_options, options()),
    identical(previous_search, search()),
    !length(list.files(directory, all.files = TRUE, no.. = TRUE)),
    !any(c('ComptoxR', 'localcatalogue') %in% loadedNamespaces())
  )
  cat('Loading: no client, file generation, search path or option changes.\n')
}
if (sys.nframe() == 0L) {
  loading_acceptance()
}
