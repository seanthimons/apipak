# Resolve input metadata independently of the default transport's supported
# subset. Explicit client mappings can use this metadata without claiming that
# the default renderer knows how to serialize it or invent a valid fixture.
input_schema <- function(
  schema,
  document,
  seen = character(),
  source_location = '#',
  parameter_items = FALSE
) {
  fail <- function(
    code,
    message,
    classification = 'schema_defect',
    at = source_location
  ) {
    schema_problem(code, classification, message, at)
  }
  if (is.null(schema)) {
    return(stats::setNames(list(), character()))
  }
  if (!is.list(schema) || is.null(names(schema))) {
    if (
      is.logical(schema) &&
        length(schema) == 1L &&
        startsWith(document$openapi %or% '', '3.1')
    ) {
      fail(
        'boolean_schema',
        'Unsupported boolean input schema',
        'capability_gap'
      )
    }
    fail('invalid_schema', 'Input schema must be an object')
  }
  ref <- schema[['$ref']]
  schema <- local_ref(
    schema,
    document,
    seen,
    source_location,
    schema_context = TRUE
  )
  if (!is.null(ref)) {
    source_location <- ref
  }
  if (is.null(names(schema))) {
    fail('invalid_schema', 'Input schema must be an object')
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
    fail(
      'invalid_type',
      'Invalid input schema type',
      at = schema_location(source_location, 'type')
    )
  }
  version <- document$openapi %or% document$swagger
  if ('type' %in% names(schema)) {
    if (
      !length(type) ||
        anyDuplicated(type) ||
        (!startsWith(version, '3.1') &&
          (length(type) != 1L || 'null' %in% type))
    ) {
      fail(
        'invalid_type',
        'Invalid input schema type for this schema version',
        at = schema_location(source_location, 'type')
      )
    }
    schema$type <- type
  }
  # OpenAPI 3.1 uses JSON Schema null types; nullable is not an assertion.
  if (startsWith(version, '3.1')) {
    schema$nullable <- NULL
  }
  if (
    identical(schema$type, 'array') &&
      is.null(schema$items) &&
      (startsWith(version, '3.0') ||
        (identical(version, '2.0') && parameter_items))
  ) {
    fail(
      'missing_array_items',
      'Array schema requires items in this schema version and parameter context',
      at = schema_location(source_location, 'items')
    )
  }
  if (!is.null(schema$properties)) {
    if (!is.list(schema$properties) || is.null(names(schema$properties))) {
      fail('invalid_properties', 'Invalid input properties')
    }
    schema$properties <- stats::setNames(
      lapply(
        names(schema$properties),
        function(name) {
          input_schema(
            schema$properties[[name]],
            document,
            seen,
            schema_location(
              schema_location(source_location, 'properties'),
              name
            )
          )
        }
      ),
      names(schema$properties)
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
    fail('invalid_required', 'Invalid required input fields')
  }
  if (!is.null(schema$items)) {
    schema$items <- input_schema(
      schema$items,
      document,
      seen,
      schema_location(source_location, 'items'),
      parameter_items
    )
  }
  for (field in intersect(names(schema), c('oneOf', 'anyOf', 'allOf'))) {
    branches <- schema[[field]]
    if (!is.list(branches) || !length(branches) || !is.null(names(branches))) {
      fail('invalid_composition', 'Invalid input schema composition')
    }
    schema[[field]] <- lapply(
      seq_along(branches),
      function(i) {
        input_schema(
          branches[[i]],
          document,
          seen,
          schema_location(schema_location(source_location, field), i - 1L)
        )
      }
    )
  }
  if (
    'additionalProperties' %in%
      names(schema) &&
      !is.list(schema$additionalProperties) &&
      !(is.logical(schema$additionalProperties) &&
        length(schema$additionalProperties) == 1L &&
        !is.na(schema$additionalProperties))
  ) {
    fail(
      'invalid_additional_properties',
      'additionalProperties must be a boolean or schema object'
    )
  }
  if (is.list(schema$additionalProperties)) {
    schema$additionalProperties <- input_schema(
      schema$additionalProperties,
      document,
      seen,
      schema_location(source_location, 'additionalProperties')
    )
  }
  schema
}
