# Normalize only encodings whose flat wire representation is defined.
parameter_shape <- function(p, schema, version, at) {
  fail <- function(code, message, classification = 'capability_gap') {
    schema_problem(code, classification, message, at)
  }
  location <- p[['in']]
  if (any(c('oneOf', 'anyOf', 'allOf') %in% names(schema))) {
    fail('parameter_composition', 'Unsupported parameter composition')
  }
  scalar <- function(s) {
    if (identical(s$format, 'binary')) {
      fail(
        'binary_parameter',
        'Binary parameter requires source contract review (#16)',
        'review_required'
      )
    }
    !any(c('oneOf', 'anyOf', 'allOf') %in% names(s)) &&
      length(s$type) == 1L &&
      s$type %in% c('string', 'integer', 'number', 'boolean')
  }
  if (identical(schema$type, 'array')) {
    if (!scalar(schema$items)) {
      fail('parameter_shape', 'Unsupported parameter array items')
    }
  } else if (identical(schema$type, 'object')) {
    children <- schema$properties
    if (is.list(schema$additionalProperties)) {
      children <- c(children, list(schema$additionalProperties))
    }
    if (
      any(vapply(children, function(s) length(s) && !scalar(s), logical(1)))
    ) {
      fail('nested_parameter', 'Unsupported nested parameter object')
    }
  } else if (!scalar(schema)) {
    fail('parameter_shape', 'Unsupported parameter type')
  }
  if (!location %in% c('path', 'query', 'header', 'cookie')) {
    fail('parameter_location', 'Unsupported parameter location')
  }
  if (!is.null(p$content) || isTRUE(p$allowReserved)) {
    fail('parameter_encoding', 'Unsupported parameter serialization')
  }
  if (identical(version, '2.0')) {
    if (location == 'cookie' || identical(schema$type, 'object')) {
      fail(
        'parameter_location',
        'Unsupported Swagger parameter location or type',
        'schema_defect'
      )
    }
    collection <- p$collectionFormat %or% 'csv'
    if (
      identical(schema$type, 'array') &&
        (!collection %in% c('csv', 'ssv', 'tsv', 'pipes', 'multi') ||
          (collection == 'multi' && location != 'query'))
    ) {
      fail(
        'collection_format',
        'Invalid Swagger collectionFormat for parameter location',
        'schema_defect'
      )
    }
    style <- if (location == 'query') 'form' else 'simple'
    explode <- identical(schema$type, 'array') && collection == 'multi'
  } else {
    collection <- NULL
    style <- p$style %or%
      if (location %in% c('path', 'header')) 'simple' else 'form'
    explode <- p$explode %or% (style == 'form')
    allowed <- switch(
      location,
      path = c('simple', 'label', 'matrix'),
      query = c('form', 'spaceDelimited', 'pipeDelimited', 'deepObject'),
      header = 'simple',
      cookie = 'form'
    )
    if (
      length(style) != 1L ||
        !style %in% allowed ||
        !is.logical(explode) ||
        length(explode) != 1L ||
        is.na(explode) ||
        (style %in%
          c('spaceDelimited', 'pipeDelimited') &&
          !identical(schema$type, 'array')) ||
        (style == 'deepObject' &&
          (!identical(schema$type, 'object') || !explode))
    ) {
      fail('parameter_encoding', 'Unsupported parameter serialization')
    }
  }
  list(
    style = style,
    explode = explode,
    collection_format = if (identical(schema$type, 'array')) {
      collection
    } else {
      NULL
    }
  )
}

# Preserve existing helper calls for the previously supported subset.
extended_parameter <- function(p) {
  if (!p$location %in% c('query', 'path', 'header', 'cookie')) {
    return(FALSE)
  }
  p$location == 'cookie' ||
    identical(p$schema$type, 'object') ||
    !is.null(p$collection_format) ||
    (!is.null(p$style) && !p$style %in% c('simple', 'form')) ||
    (identical(p$schema$type, 'array') &&
      !(p$location == 'query' && identical(p$schema$items$type, 'string')))
}
