# Read-only corpus verification against the installed checkout.
verify_composition <- function(
  root = 'C:/Users/sxthi/Documents/specmill-testing',
  output = 'dev/audits/composition'
) {
  source('dev/audit_proving_ground.R', local = TRUE)
  source('dev/verify_schema_gaps.R', local = TRUE)
  active <- audit_proving_ground(root, file.path(output, 'active'))
  before <- read.csv('dev/audits/proving-ground/schema-gaps/operations.csv')
  after <- active$diagnostics
  key <- function(x) paste(x$service, x$method, x$path)
  gained <- before[!key(before) %in% key(after), ]
  exposed <- after[
    !key(after) %in% key(before) |
      after$reason != before$reason[match(key(after), key(before))],
  ]
  stopifnot(
    length(active$plan$operations) == 332L,
    length(active$plan$excluded) == 205L,
    nrow(after) == 11L,
    nrow(exposed) == 0L,
    setequal(
      paste(gained$method, gained$path),
      c(
        'POST /api/amnb_nate',
        'POST /api/ncc_cats',
        'POST /api/opera',
        'POST /api/predictor_models/predict'
      )
    ),
    setequal(
      key(before[before$classification == 'schema_defect', ]),
      key(after[after$classification == 'schema_defect', ])
    )
  )
  write.csv(
    gained,
    file.path(output, 'active', 'gained-operations.csv'),
    row.names = FALSE
  )
  write.csv(
    exposed,
    file.path(output, 'active', 'exposed-blockers.csv'),
    row.names = FALSE
  )
  checks <- lapply(seq_len(nrow(gained)), function(i) {
    row <- gained[i, ]
    selected <- Filter(
      function(op) {
        identical(op$service, row$service) &&
          identical(op$key, paste(row$method, row$path))
      },
      active$plan$operations
    )
    stopifnot(length(selected) == 1L)
    op <- selected[[1L]]
    inputs <- specmill::operation_fixtures(list(op))[[1L]]
    runtime <- new.env(parent = baseenv())
    runtime$record_request <- function(...) list(...)
    eval(
      parse(
        text = specmill::render_operation(op, list(helper = 'record_request'))
      ),
      runtime
    )
    request <- do.call(runtime[[op$name]], inputs)
    stopifnot(
      identical(request$method, row$method),
      identical(request$path, row$path)
    )
    data.frame(
      service = row$service,
      key = op$key,
      body = as.character(jsonlite::toJSON(
        request$body,
        auto_unbox = TRUE,
        null = 'null'
      ))
    )
  })
  write.csv(
    do.call(rbind, checks),
    file.path(output, 'active', 'fixture-invocations.csv'),
    row.names = FALSE
  )
  mirrored <- verify_schema_gaps(
    native_root = file.path(root, 'additional-schemas'),
    baseline = 'dev/audits/bracket-arrays',
    baseline_caveats = NULL,
    output = file.path(output, 'additional'),
    policies = setNames(
      list(list(query_array_style = 'brackets')),
      'stripe/openapi/master/openapi/spec3.yaml'
    )
  )
  invisible(list(
    active = active,
    gained = gained,
    exposed = exposed,
    mirrored = mirrored
  ))
}
