# Source after installing the checkout; this audit never writes to the client.
verify_parameter_serialization <- function(
  root = 'C:/Users/sxthi/Documents/specmill-testing',
  output = 'dev/audits/proving-ground/parameters'
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
  old <- read.csv('dev/audits/proving-ground/json-shapes/operations.csv')
  current <- result$diagnostics
  key <- function(x) paste(x$service, x$method, x$path)
  newly_blocked <- current[!key(current) %in% key(old), ]
  changed <- merge(
    old,
    current,
    by = c('service', 'method', 'path'),
    suffixes = c('_before', '_after')
  )
  changed <- changed[changed$reason_before != changed$reason_after, ]
  native <- do.call(
    rbind,
    lapply(result$plan$diagnostics, function(x) {
      as.data.frame(
        x[c(
          'service',
          'key',
          'classification',
          'code',
          'source_location',
          'reason'
        )],
        stringsAsFactors = FALSE
      )
    })
  )
  stopifnot(
    length(result$plan$operations) == 328L,
    length(result$plan$excluded) == 205L,
    nrow(current) == 15L,
    !length(setdiff(key(old), key(current))),
    identical(
      key(newly_blocked),
      'alerts_library_controller POST /api/alerts/groups'
    ),
    setequal(
      key(changed),
      c(
        'alerts_alerts_controller POST /api/alerts',
        'hazard_hazard_controller POST /api/hazard',
        'resolver_default POST /api/resolver/safety-flags',
        'standardizer_library_controller POST /api/stdizer/groups',
        'standardizer_stdizer_controller POST /api/stdizer',
        'toxprints_toxprints_controller POST /api/toxprints/calculate'
      )
    ),
    sum(native$code == 'binary_parameter') == 7L,
    sum(native$classification == 'review_required') == 7L,
    sum(native$code == 'body_composition') == 4L,
    setequal(
      key(old[old$classification == 'schema_defect', ]),
      key(current[current$classification == 'schema_defect', ])
    )
  )
  write.csv(
    changed,
    file.path(output, 'changed-blockers.csv'),
    row.names = FALSE
  )
  write.csv(
    newly_blocked,
    file.path(output, 'newly-blocked.csv'),
    row.names = FALSE
  )
  write.csv(
    native,
    file.path(output, 'native-diagnostics.csv'),
    row.names = FALSE
  )
  invisible(result)
}
