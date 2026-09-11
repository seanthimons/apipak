schema_location <- function(parent, token) {
  paste0(
    parent,
    '/',
    gsub('/', '~1', gsub('~', '~0', token, fixed = TRUE), fixed = TRUE)
  )
}

schema_problem <- function(code, classification, message, source_location) {
  stop(structure(
    list(
      message = message,
      call = NULL,
      code = code,
      classification = classification,
      source_location = source_location
    ),
    class = c('specmill_schema_problem', 'error', 'condition')
  ))
}

diagnostic_fields <- function(problem, source_location) {
  classification <- problem$classification %or% 'review_required'
  guidance <- switch(
    classification,
    schema_defect = 'Verify the source contract and correct the schema or use an explicitly retained implementation; do not guess a replacement.',
    capability_gap = 'Review supported configuration or a complete client mapping; keep the operation visible until generator support is available.',
    'Review the source and configuration at this location; this diagnostic does not establish schema validity.'
  )
  if (
    any(
      problem$code %in%
        c('external_reference', 'local_reference', 'recursive_reference')
    )
  ) {
    guidance <- 'Review reference support and retain the operation for follow-up; a client mapping cannot bypass unresolved input metadata.'
  }
  list(
    classification = classification,
    code = problem$code %or% 'unclassified_error',
    source_location = problem$source_location %or% source_location,
    guidance = guidance
  )
}
