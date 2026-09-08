# Reuse the extracted endpoint table for both clients. The neutral boundary
# adds validated source metadata that legacy comma-separated columns cannot
# represent (location identity, serialization and explicit default presence).
endpoint_records <- function(document, operations) {
  context <- new.env(parent = asNamespace('wrapmaint'))
  context[['%||%']] <- function(x, y) {
    if (is.null(x) || is.atomic(x) && length(x) == 1L && is.na(x)) y else x
  }
  context$supported_methods <- c(
    'get',
    'post',
    'put',
    'patch',
    'delete',
    'head',
    'options'
  )
  context$PAGINATION_REGISTRY <- list()
  context$body_requires_resolution <- function(...) FALSE
  context$get_body_schema_type <- function(body, document) {
    schema <- local_ref(body$content[['application/json']]$schema, document)
    if (identical(schema$type, 'object')) {
      'simple_object'
    } else {
      schema$type %or% 'unknown'
    }
  }
  bind_tools('schema', context)
  bind_tools('parser', context)
  # Pagination inference is client policy. A neutral page parameter remains
  # an ordinary scalar input and must not trigger EPA-specific diagnostics.
  context$detect_pagination <- function(...) list(strategy = 'none')
  # Unsupported operations must not be sent to the compatibility parser.
  paths <- list()
  for (op in operations) {
    path <- document$paths[[op$path]]
    paths[[op$path]][[tolower(op$method)]] <- path[[tolower(op$method)]]
    paths[[op$path]]$parameters <- path$parameters
  }
  document$paths <- paths
  table <- suppressMessages(context$openapi_to_spec(
    document,
    preprocess = FALSE
  ))
  keys <- paste(table$method, table$route)
  rows <- match(vapply(operations, `[[`, character(1), 'key'), keys)
  lapply(seq_along(operations), function(index) {
    op <- operations[[index]]
    row <- rows[[index]]
    if (is.na(row)) {
      stop(
        'Supported operation was not represented by the shared parser: ',
        op$key
      )
    }
    record <- lapply(table[row, , drop = FALSE], `[[`, 1L)
    record$needs_resolver <- NULL
    utils::modifyList(record, op, keep.null = TRUE)
  })
}
