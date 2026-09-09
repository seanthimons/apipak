retire_unused_hooks <- function(root, apply = FALSE) {
  root <- normalizePath(root, winslash = '/', mustWork = TRUE)
  callbacks <- new.env(parent = baseenv())
  sys.source(file.path(root, 'dev/apipak_callbacks.R'), callbacks)
  selected <- vapply(apipak::inspect_client(root, callbacks = callbacks)$operations, `[[`, character(1), 'name')
  absent <- c('ct_chemical_list_by_name', 'ct_chemical_list',
    'ct_chemical_property_experimental_bulk', 'ct_chemical_property_predicted_bulk',
    'epi_ecosar_surfactant', 'epi_ecosar_polymer')
  definitions <- apipak:::client_definitions(root)
  calls <- unique(unlist(lapply(definitions, `[[`, 'call_names')))
  stopifnot(!any(absent %in% c(selected, names(definitions), calls)))
  path <- file.path(root, 'inst/hook_config.yml')
  before <- yaml::read_yaml(path)
  if (!any(absent %in% names(before))) return(invisible(absent))
  stopifnot(all(absent %in% names(before)))
  lines <- readLines(path, warn = FALSE)
  starts <- which(grepl('^[A-Za-z][A-Za-z0-9_]*:', lines))
  keys <- sub(':.*$', '', lines[starts])
  ends <- c(starts[-1L] - 1L, length(lines))
  drop <- unlist(Map(seq.int, starts[keys %in% absent], ends[keys %in% absent]))
  after <- lines[-drop]
  stopifnot(identical(yaml::yaml.load(paste(after, collapse = '\n')), before[setdiff(names(before), absent)]))
  if (apply) writeLines(after, path)
  cat('Six hook declarations have no selected public operation, runtime definition or caller; remaining configuration is identical.\n')
  invisible(absent)
}
if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  retire_unused_hooks(args[[1L]], '--apply' %in% args)
}
