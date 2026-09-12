# Explicit opt-in on the mirrored Stripe input only. No source/config writes.
verify_bracket_arrays <- function(
  native_root = 'C:/Users/sxthi/Documents/specmill-testing/additional-schemas',
  output = 'dev/audits/bracket-arrays'
) {
  source('dev/audit_testing_specs.R', local = TRUE)
  stripe <- 'stripe/openapi/master/openapi/spec3.yaml'
  baseline <- read.csv('dev/audits/schema-gaps/operations.csv')
  defaults <- specmill::read_operations(file.path(native_root, stripe))
  stopifnot(
    length(defaults$operations) == 26L,
    length(defaults$diagnostics) == 568L
  )
  result <- audit_testing_specs(
    output = output,
    native_root = native_root,
    report = FALSE,
    policies = setNames(list(list(query_array_style = 'brackets')), stripe)
  )
  compared <- merge(
    baseline,
    result$operations,
    by = c('file', 'key'),
    all = TRUE,
    suffixes = c('_before', '_after')
  )
  changed <- compared[
    is.na(compared$stage_before) |
      is.na(compared$stage_after) |
      compared$stage_before != compared$stage_after |
      compared$reason_before != compared$reason_after,
  ]
  stopifnot(all(changed$file == stripe))
  write.csv(
    changed,
    file.path(output, 'changed-operations.csv'),
    row.names = FALSE
  )
  exposed <- changed[changed$stage_after != 'passed', ]
  write.csv(
    exposed,
    file.path(output, 'exposed-blockers.csv'),
    row.names = FALSE
  )
  summary <- result$schemas[result$schemas$file == stripe, ]
  print(summary[c('selected', 'diagnosed', 'fixtures', 'invoked')])
  invisible(list(result = result, changed = changed, exposed = exposed))
}
