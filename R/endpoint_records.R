# Reuse the extracted endpoint table for both clients. The neutral boundary
# adds validated source metadata that legacy comma-separated columns cannot
# represent (location identity, serialization and explicit default presence).
endpoint_records <- function(document, operations) {
  context <- new.env(parent = asNamespace('specmill'))
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
    body <- local_ref(body, document)
    content <- body$content %||% list()
    media <- intersect(
      c(
        'application/json',
        'application/octet-stream',
        'application/x-www-form-urlencoded',
        'multipart/form-data'
      ),
      names(content)
    )
    if (
      !length(media) ||
        media[[1L]] %in%
          c(
            'application/x-www-form-urlencoded',
            'multipart/form-data'
          )
    ) {
      return('unknown')
    }
    schema <- content[[media[[1L]]]]$schema
    if (is.null(schema) || !is.list(schema)) {
      return('unknown')
    }
    schema <- local_ref(schema, document)
    if (schema_type_is(schema$type, 'object')) {
      'simple_object'
    } else if (
      is.character(schema$type) &&
        length(schema$type) == 1L &&
        !is.na(schema$type)
    ) {
      schema$type
    } else {
      'unknown'
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
  parse <- function(input) {
    suppressMessages(context$openapi_to_spec(
      input,
      preprocess = FALSE
    ))
  }
  record <- function(table, op) {
    keys <- paste(table$method, table$route)
    row <- match(op$key, keys)
    if (is.na(row)) {
      stop(
        'Supported operation was not represented by the shared parser: ',
        op$key
      )
    }
    output <- lapply(table[row, , drop = FALSE], `[[`, 1L)
    output$needs_resolver <- NULL
    utils::modifyList(output, op, keep.null = TRUE)
  }
  table <- tryCatch(parse(document), error = identity)
  if (!inherits(table, 'error')) {
    records <- lapply(operations, function(op) {
      tryCatch(record(table, op), error = identity)
    })
    if (!any(vapply(records, inherits, logical(1), 'error'))) {
      return(records)
    }
  }

  # Keep one malformed compatibility record from aborting its document. The
  # normal path above still parses the document only once.
  diagnostics <- list()
  records <- lapply(operations, function(op) {
    item <- document$paths[[op$path]]
    one <- document
    one$paths <- list()
    one$paths[[op$path]] <- list()
    one$paths[[op$path]]$parameters <- item$parameters
    one$paths[[op$path]][[tolower(op$method)]] <- item[[tolower(op$method)]]
    parsed <- tryCatch(parse(one), error = identity)
    if (!inherits(parsed, 'error')) {
      parsed <- tryCatch(record(parsed, op), error = identity)
      if (!inherits(parsed, 'error')) {
        return(parsed)
      }
    }
    op$parser_failure <- conditionMessage(parsed)
    diagnostics[[length(diagnostics) + 1L]] <<- list(
      key = op$key,
      code = 'parser_failure',
      reason = op$parser_failure
    )
    op
  })
  attr(records, 'parser_diagnostics') <- diagnostics
  records
}
