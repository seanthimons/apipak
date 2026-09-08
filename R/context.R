# Compatibility functions run with explicitly supplied client policy.
# No client is loaded, sourced, or attached by package installation or loading.
bind_tools <- function(group, envir) {
  stopifnot(is.environment(envir), group %in% names(tool_groups))
  for (package in c('dplyr', 'purrr', 'stringr', 'tibble', 'tidyr', 'cli')) {
    for (name in getNamespaceExports(package)) {
      if (!exists(name, envir = envir, inherits = TRUE)) {
        assign(name, getExportedValue(package, name), envir = envir)
      }
    }
  }
  if (group == 'schema') {
    assign('resolve_stack', new.env(hash = TRUE, parent = emptyenv()), envir)
  }
  for (name in tool_groups[[group]]) {
    fn <- get(name, envir = asNamespace('wrapmaint'))
    environment(fn) <- envir
    assign(name, fn, envir = envir)
  }
  invisible(envir)
}

`%or%` <- function(x, y) if (is.null(x)) y else x

# Escape schema strings as R literals. No remote text is evaluated as code.
r_literal <- function(x) paste(deparse(x, width.cutoff = 500L), collapse = '\n')

local_ref <- function(node, document, seen = character()) {
  ref <- node[['$ref']]
  if (is.null(ref)) return(node)
  if (length(ref) != 1L || !startsWith(ref, '#/') || ref %in% seen) {
    stop('Unsupported external or cyclic reference: ', ref, call. = FALSE)
  }
  parts <- strsplit(sub('^#/', '', ref), '/', fixed = TRUE)[[1]]
  parts <- gsub('~1', '/', gsub('~0', '~', parts, fixed = TRUE), fixed = TRUE)
  value <- document
  for (part in parts) value <- value[[part]]
  if (is.null(value)) stop('Missing reference: ', ref, call. = FALSE)
  local_ref(value, document, c(seen, ref))
}
