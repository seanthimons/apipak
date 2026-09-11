# Compatibility functions run with explicitly supplied client policy.
# No client is loaded, sourced, or attached by package installation or loading.
# These names are the explicit compatibility context contract, plus columns
# evaluated by the existing data-frame pipelines. bind_tools() rebinds the
# compatibility functions into the client environment that supplies policy.
utils::globalVariables(c(
  '.fn',
  '.fn_file',
  'endpoint_key',
  'file_full',
  'file_short',
  'fn',
  'fn_full',
  'fn_short',
  'method',
  'n_hits',
  'n_short_count',
  'route',
  'ENDPOINT_PATTERNS_TO_EXCLUDE',
  'FRAMEWORK_PARAMS',
  'PAGINATION_REGISTRY',
  'body_requires_resolution',
  'get_body_schema_type',
  'render_endpoint_stubs',
  'resolve_stack',
  'select_schema_files',
  'supported_methods',
  'tg_config'
))
bind_tools <- function(group, envir) {
  stopifnot(is.environment(envir), group %in% names(tool_groups))
  for (package in if (group != 'readiness') {
    c('dplyr', 'purrr', 'stringr', 'tibble', 'tidyr', 'cli')
  }) {
    for (name in getNamespaceExports(package)) {
      if (!exists(name, envir = envir, inherits = FALSE)) {
        assign(name, getExportedValue(package, name), envir = envir)
      }
    }
  }
  if (group == 'schema') {
    assign('resolve_stack', new.env(hash = TRUE, parent = emptyenv()), envir)
  }
  for (name in tool_groups[[group]]) {
    fn <- get(name, envir = asNamespace('specmill'))
    if (is.function(fn)) {
      environment(fn) <- envir
    }
    assign(name, fn, envir = envir)
  }
  invisible(envir)
}

`%or%` <- function(x, y) if (is.null(x)) y else x

# Escape schema strings as R literals. No remote text is evaluated as code.
r_literal <- function(x) paste(deparse(x, width.cutoff = 500L), collapse = '\n')

local_ref <- function(
  node,
  document,
  seen = character(),
  source_location = '#'
) {
  fail <- function(code, message, classification = 'schema_defect') {
    schema_problem(code, classification, message, source_location)
  }
  if (!is.list(node)) {
    fail('invalid_reference_target', 'Reference target must be an object')
  }
  ref <- node[['$ref']]
  if (is.null(ref)) {
    return(node)
  }
  if (!is.character(ref) || length(ref) != 1L || is.na(ref)) {
    fail('invalid_reference', 'Reference must be a string')
  }
  if (!startsWith(ref, '#/')) {
    fail(
      if (startsWith(ref, '#')) 'local_reference' else 'external_reference',
      paste(
        if (startsWith(ref, '#')) {
          'Unsupported local reference fragment:'
        } else {
          'Unsupported external reference:'
        },
        ref
      ),
      'capability_gap'
    )
  }
  if (ref %in% seen) {
    fail(
      'recursive_reference',
      paste('Unsupported local recursive reference:', ref),
      'capability_gap'
    )
  }
  parts <- strsplit(sub('^#/', '', ref), '/', fixed = TRUE)[[1]]
  if (any(grepl('~([^01]|$)', parts))) {
    fail('invalid_reference', paste('Invalid reference escape:', ref))
  }
  parts <- gsub('~0', '~', gsub('~1', '/', parts, fixed = TRUE), fixed = TRUE)
  value <- document
  for (part in parts) {
    if (!is.list(value)) {
      fail('unresolved_reference', paste('Missing reference:', ref))
    }
    value <- value[[part]]
  }
  if (is.null(value)) {
    fail('unresolved_reference', paste('Missing reference:', ref))
  }
  local_ref(value, document, c(seen, ref), ref)
}
