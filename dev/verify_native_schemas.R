# Source after installing the checkout. No Python conversion or API requests.
verify_native_schemas <- function(
  root = 'C:/Users/sxthi/Documents/specmill-testing/additional-schemas',
  output = 'dev/audits/native-yaml'
) {
  source('dev/audit_testing_specs.R', local = TRUE)
  result <- audit_testing_specs(output = output, native_root = root)
  old <- read.csv('dev/audits/additional-schemas/operations.csv')
  current <- result$operations
  compared <- merge(
    old,
    current,
    by = c('file', 'key'),
    all = TRUE,
    suffixes = c('_before', '_after')
  )
  compared <- compared[
    is.na(compared$stage_before) |
      is.na(compared$stage_after) |
      compared$stage_before != compared$stage_after |
      compared$reason_before != compared$reason_after,
  ]
  write.csv(
    compared,
    file.path(output, 'changed-operations.csv'),
    row.names = FALSE
  )
  previous <- read.csv('dev/audits/additional-schemas/schemas.csv')
  documents <- merge(
    previous,
    result$schemas,
    by = 'file',
    suffixes = c('_before', '_after')
  )
  write.csv(
    documents,
    file.path(output, 'document-comparison.csv'),
    row.names = FALSE
  )
  error_kind <- function(x) {
    sub('^(Missing paths:|Unsupported schema version in) .*$', '\\1', x)
  }
  stopifnot(
    nrow(result$schemas) == 33L,
    !'worker_error' %in% names(result$schemas),
    nrow(compared) == 0L,
    sum(result$schemas$selected) == 2186L,
    sum(result$schemas$diagnosed) == 660L,
    sum(result$schemas$invoked) == 2183L,
    !any(nzchar(result$schemas$warnings)),
    identical(
      error_kind(documents$parser_error_before),
      error_kind(documents$parser_error_after)
    )
  )
  cat(
    nrow(compared),
    'changed operation records versus the converted-JSON baseline.\n'
  )
  invisible(result)
}
