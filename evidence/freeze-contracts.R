freeze_contracts <- function(root, output, library) {
  .libPaths(c(library, .libPaths()))
  root <- normalizePath(root, winslash = '/', mustWork = TRUE)
  output <- normalizePath(output, winslash = '/', mustWork = TRUE)
  previous <- setwd(root)
  on.exit(setwd(previous), add = TRUE)
  env <- new.env(parent = baseenv())
  sys.source(file.path(root, 'dev/toolkit_adapter.R'), env)
  context <- env$comptox_tools(root)
  inventories <- lapply(context$api_specs, function(spec) spec$build_endpoints())
  saveRDS(inventories, file.path(output, 'selected-operations.rds'))
  jsonlite::write_json(inventories, file.path(output, 'selected-operations.json'), pretty = TRUE, auto_unbox = TRUE, null = 'null')
  ownership <- new.env(parent = baseenv())
  sys.source(file.path(root, 'dev/remove_experimental.R'), ownership)
  files <- list.files(file.path(root, 'R'), '\\.R$', full.names = TRUE)
  contracts <- setNames(lapply(files, function(path) {
    expressions <- parse(path, keep.source = FALSE)
    definitions <- Filter(function(x) is.call(x) && identical(x[[1L]], as.name('<-')) &&
      length(x) == 3L && is.call(x[[3L]]) && identical(x[[3L]][[1L]], as.name('function')), as.list(expressions))
    list(ownership = ownership$classify_experimental_file(path),
      definitions = lapply(definitions, function(x) list(name = as.character(x[[2L]]),
        formals = paste(deparse(x[[3L]][[2L]]), collapse = '\n'), code = paste(deparse(x[[3L]]), collapse = '\n'))),
      documentation = grep("^#'", readLines(path, warn = FALSE, encoding = 'UTF-8'), value = TRUE))
  }), basename(files))
  saveRDS(contracts, file.path(output, 'public-contracts.rds'))
  jsonlite::write_json(contracts, file.path(output, 'public-contracts.json'), pretty = TRUE, auto_unbox = TRUE, null = 'null')
  print(vapply(inventories, function(x) if (is.null(x)) 0L else nrow(x), integer(1)))
  invisible(contracts)
}
if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  freeze_contracts(args[[1L]], args[[2L]], args[[3L]])
}
