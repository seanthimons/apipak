# Source from the specmill checkout after installing the current package.
verify_json_shapes <- function(
  root = 'C:/Users/sxthi/Documents/specmill-testing',
  output = 'dev/audits/proving-ground/json-shapes'
) {
  source('dev/audit_proving_ground.R', local = TRUE)
  files <- list.files(
    root,
    recursive = TRUE,
    all.files = TRUE,
    full.names = TRUE
  )
  before <- tools::md5sum(files)
  result <- audit_proving_ground(root, output)
  stopifnot(
    identical(
      files,
      list.files(root, recursive = TRUE, all.files = TRUE, full.names = TRUE)
    ),
    identical(before, tools::md5sum(files))
  )
  old <- read.csv('dev/audits/proving-ground/filtered/operations.csv')
  current <- result$diagnostics
  key <- function(x) paste(x$service, x$method, x$path)
  unblocked <- old[!key(old) %in% key(current), ]
  changed <- merge(
    old,
    current,
    by = c('service', 'method', 'path'),
    suffixes = c('_before', '_after')
  )
  changed <- changed[changed$reason_before != changed$reason_after, ]
  stopifnot(
    length(result$plan$operations) == 329L,
    length(result$plan$excluded) == 205L,
    nrow(current) == 14L,
    nrow(unblocked) == 36L,
    nrow(changed) == 2L,
    !length(setdiff(key(current), key(old))),
    all(changed$reason_after == 'Unsupported parameter type'),
    setequal(
      key(old[old$classification == 'schema_defect', ]),
      key(current[current$classification == 'schema_defect', ])
    )
  )
  write.csv(unblocked, file.path(output, 'unblocked.csv'), row.names = FALSE)
  write.csv(
    changed,
    file.path(output, 'changed-blockers.csv'),
    row.names = FALSE
  )
  rows <- function(x) {
    paste0('| ', x$service, ' | `', x$method, ' ', x$path, '` |')
  }
  writeLines(
    c(
      '# Issue #14: JSON shape verification',
      '',
      'Verified 2026-09-11 against the installed development package.',
      '',
      'The reviewed 27 API files / 69 groups remain unchanged. The read-only audit',
      'hashes every existing proving-ground file before and after planning.',
      'No public API requests or generated-client writes were made.',
      '',
      '| Disposition | Before | After |',
      '| --- | ---: | ---: |',
      '| Renderable | 293 | 329 |',
      '| Excluded | 205 | 205 |',
      '| Blocked | 50 | 14 |',
      '',
      'All 36 standalone #14 blockers became renderable. The two shared blockers',
      'below lost their open-object diagnostic and retain only parameter-type',
      'limitations under #8. No newly exposed blocker reason or newly blocked key',
      'was found. Remaining blockers: six parameter types (#8), four compositions',
      '(#12), and the same four invalid AMOS types (#16). Source schemas, reviewed',
      'exclusions, operation names, configuration, and client-owned helpers were',
      'not modified. Renderability does not verify a remote service contract.',
      '',
      '## Operations now renderable',
      '',
      '| Service | Operation key |',
      '| --- | --- |',
      rows(unblocked),
      '',
      '## Shared blockers now owned solely by #8',
      '',
      '| Service | Operation key |',
      '| --- | --- |',
      rows(changed),
      '',
      'Both now report `Unsupported parameter type`; before they also reported',
      '`Unsupported free-form body object`. Full before/after records are in',
      '[changed-blockers.csv](changed-blockers.csv). Remaining operation-level',
      'evidence is in [operations.csv](operations.csv).',
      '',
      '## Reproduce',
      '',
      '```r',
      "source('dev/verify_json_shapes.R')",
      'verify_json_shapes()',
      '```',
      '',
      'Install the checkout first; the audit deliberately uses installed specmill.',
      'Regression tests are independent of this external corpus and run offline:',
      '',
      '```r',
      "source('tests/native-transport.R'); native_transport_acceptance()",
      "source('tests/nested-bodies.R'); nested_body_acceptance()",
      "source('tests/diagnostics.R'); diagnostics_acceptance()",
      '```',
      '',
      'The localhost server verifies exact received JSON bytes for empty/populated',
      'objects, typed maps, heterogeneous and nested arrays, null, omission, and',
      'both normal and byte-limited serialization. A counting transport proves',
      'invalid inputs fail before transport. Fixture checks use the same validator;',
      'a 10,000-entry map checks the bulk path. Existing Petstore transport contracts',
      'and the natural-products frozen-schema acceptance remain covered.',
      '',
      '## Schema semantics and limits',
      '',
      'The implementation follows [OpenAPI 3.0 Schema Objects](https://spec.openapis.org/oas/v3.0.3.html#schema-object),',
      '[Swagger 2 body schemas](https://spec.openapis.org/oas/v2.0.html#schema-object),',
      'and [Draft 4 array/object validation](https://json-schema.org/draft-04/draft-fge-json-schema-validation-00).',
      'Examples supply fixtures only; they do not establish types. Composition,',
      'recursive schemas, boolean schemas, and union/null type declarations remain',
      'outside this slice. See the configuration guide for accepted R input shapes.'
    ),
    file.path(output, 'RESULTS.md')
  )
  invisible(result)
}
