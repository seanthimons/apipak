# Resolve input metadata independently of the default transport's supported
# subset. Explicit client mappings can use this metadata without claiming that
# the default renderer knows how to serialize it or invent a valid fixture.
input_schema <- function(schema, document, seen = character()) {
  if (is.null(schema)) {
    return(stats::setNames(list(), character()))
  }
  if (!is.list(schema) || is.null(names(schema))) {
    stop('Input schema must be an object')
  }
  ref <- schema[['$ref']]
  schema <- local_ref(schema, document, seen)
  if (is.null(names(schema))) {
    stop('Input schema must be an object')
  }
  seen <- c(seen, ref)
  type <- unlist(schema$type, use.names = FALSE)
  if (
    length(type) &&
      (!is.character(type) ||
        any(
          !type %in%
            c(
              'string',
              'integer',
              'number',
              'boolean',
              'object',
              'array',
              'null'
            )
        ))
  ) {
    stop('Invalid input schema type')
  }
  if (!is.null(schema$properties)) {
    if (!is.list(schema$properties) || is.null(names(schema$properties))) {
      stop('Invalid input properties')
    }
    schema$properties <- lapply(
      schema$properties,
      input_schema,
      document = document,
      seen = seen
    )
  }
  required <- unlist(schema$required, use.names = FALSE)
  if (
    length(required) &&
      (!is.character(required) ||
        anyNA(required) ||
        anyDuplicated(required) ||
        any(!nzchar(required)))
  ) {
    stop('Invalid required input fields')
  }
  if (!is.null(schema$items)) {
    schema$items <- input_schema(schema$items, document, seen)
  }
  for (field in intersect(names(schema), c('oneOf', 'anyOf', 'allOf'))) {
    branches <- schema[[field]]
    if (!is.list(branches) || !length(branches) || !is.null(names(branches))) {
      stop('Invalid input schema composition')
    }
    schema[[field]] <- lapply(
      branches,
      input_schema,
      document = document,
      seen = seen
    )
  }
  if (
    !is.null(schema$additionalProperties) &&
      !is.logical(schema$additionalProperties)
  ) {
    schema$additionalProperties <- input_schema(
      schema$additionalProperties,
      document,
      seen
    )
  }
  schema
}
