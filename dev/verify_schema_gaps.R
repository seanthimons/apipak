# Re-run mirrored native sources against the installed current package and
# compare operation records without historical-count assertions.
verify_schema_gaps <- function(
  native_root = 'C:/Users/sxthi/Documents/specmill-testing/additional-schemas',
  baseline = 'dev/audits/native-yaml',
  baseline_caveats = 'dev/audits/additional-schemas/coverage-caveats.csv',
  output = 'dev/audits/schema-gaps'
) {
  source('dev/audit_testing_specs.R', local = TRUE)
  result <- audit_testing_specs(
    output = output,
    native_root = native_root,
    report = FALSE
  )
  before <- read.csv(
    file.path(baseline, 'operations.csv'),
    stringsAsFactors = FALSE
  )
  after <- result$operations
  caveats <- read.csv(baseline_caveats, stringsAsFactors = FALSE)
  id <- function(x) paste(x$file, x$key)
  before$resolved <- before$stage == 'passed' & !id(before) %in% id(caveats)
  after$resolved <- after$stage == 'passed'
  changed <- merge(
    before,
    after,
    by = c('file', 'key'),
    all = TRUE,
    suffixes = c('_before', '_after')
  )
  stage_or_reason_changed <-
    is.na(changed$stage_before) |
    is.na(changed$stage_after) |
    changed$stage_before != changed$stage_after |
    changed$reason_before != changed$reason_after
  resolution_changed <- !is.na(changed$resolved_before) &
    !is.na(changed$resolved_after) &
    changed$resolved_before != changed$resolved_after
  changed <- changed[stage_or_reason_changed | resolution_changed, ]
  write.csv(
    changed,
    file.path(output, 'changed-operations.csv'),
    row.names = FALSE
  )
  resolved <- changed[
    !is.na(changed$resolved_before) &
      !is.na(changed$resolved_after) &
      !changed$resolved_before &
      changed$resolved_after,
    c('file', 'key', 'stage_before', 'stage_after')
  ]
  write.csv(
    resolved,
    file.path(output, 'resolved-operation-keys.csv'),
    row.names = FALSE
  )
  blockers <- changed[
    !is.na(changed$stage_after) & changed$stage_after != 'passed',
    c(
      'file',
      'key',
      'stage_after',
      'classification_after',
      'code_after',
      'reason_after'
    )
  ]
  names(blockers) <- sub('_after$', '', names(blockers))
  write.csv(blockers, file.path(output, 'new-blockers.csv'), row.names = FALSE)
  before_schemas <- read.csv(
    file.path(baseline, 'schemas.csv'),
    stringsAsFactors = FALSE
  )
  comparison <- merge(
    before_schemas,
    result$schemas,
    by = 'file',
    all = TRUE,
    suffixes = c('_before', '_after')
  )
  write.csv(
    comparison,
    file.path(output, 'document-comparison.csv'),
    row.names = FALSE
  )
  writeLines(
    c(
      '# Current schema gaps audit',
      '',
      'Runs the 33 mirrored native documents in isolated processes against the installed current package.',
      'Operation references without resolved inputs are diagnostics and are excluded from smoke coverage.',
      '',
      paste('Changed operation records:', nrow(changed)),
      paste('Resolved-contract gains:', nrow(resolved)),
      paste('Selected operations:', sum(result$schemas$selected, na.rm = TRUE)),
      paste(
        'Operation diagnostics:',
        sum(result$schemas$diagnosed, na.rm = TRUE)
      ),
      paste(
        'Resolved-contract smoke passes:',
        sum(result$operations$stage == 'passed')
      ),
      paste('New parser blockers:', sum(blockers$stage == 'parser')),
      paste('New fixture blockers:', sum(blockers$stage == 'fixture')),
      '',
      '[Schema results](schemas.csv), [operation results](operations.csv),',
      '[changed operations](changed-operations.csv), [resolved contract gains](resolved-operation-keys.csv),',
      '[new blockers](new-blockers.csv),',
      '[document comparison](document-comparison.csv).'
    ),
    file.path(output, 'SUMMARY.md')
  )
  invisible(list(result = result, changed = changed, comparison = comparison))
}
