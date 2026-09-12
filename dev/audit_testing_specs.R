# Prepare JSON with dev/prepare_testing_specs.py, then source and call this function.
# Uses installed specmill; no live API calls or active-client writes.
audit_testing_specs <- function(
  prepared = '.docs-lib/additional-json',
  output = 'dev/audits/additional-schemas',
  native_root = NULL,
  report = TRUE
) {
  inputs <- if (is.null(native_root)) {
    read.csv(
      file.path(prepared, 'inputs.csv'),
      stringsAsFactors = FALSE,
      colClasses = 'character'
    )
  } else {
    manifest <- read.csv(
      file.path(native_root, 'manifest.csv'),
      colClasses = 'character'
    )
    manifest <- manifest[manifest$tier != 'reference', ]
    manifest$source <- file.path(native_root, manifest$file)
    manifest$prepared <- manifest$source
    manifest$conversion_error <- ''
    manifest
  }
  dir.create(output, recursive = TRUE, showWarnings = FALSE)
  before <- tools::md5sum(inputs$source)
  summaries <- operations <- list()
  for (i in seq_len(nrow(inputs))) {
    input <- inputs[i, ]
    message(i, '/', nrow(inputs), ': ', input$file)
    result <- tryCatch(
      callr::r(
        function(input, native) {
          clean <- function(x) gsub('[\r\n]+', ' ', conditionMessage(x))
          attempt <- function(expr) {
            tryCatch(
              {
                force(expr)
                ''
              },
              error = clean
            )
          }
          raw_error <- if (native) {
            ''
          } else {
            attempt(specmill::read_operations(input$source))
          }
          summary <- list(
            file = input$file,
            tier = input$tier,
            version = input$version,
            raw_error = raw_error,
            conversion_error = input$conversion_error,
            parser_error = '',
            warnings = '',
            declared = NA_integer_,
            path_refs = NA_integer_,
            selected = 0L,
            diagnosed = 0L,
            rendered = 0L,
            fixtures = 0L,
            invoked = 0L
          )
          records <- list()
          if (nzchar(input$conversion_error)) {
            return(list(summary = summary, operations = records))
          }
          doc <- tryCatch(
            if (native) {
              specmill:::read_schema_document(input$source)
            } else {
              jsonlite::read_json(input$prepared)
            },
            error = function(e) {
              summary$parser_error <<- clean(e)
              NULL
            }
          )
          if (is.null(doc)) {
            if (native) {
              summary$raw_error <- summary$parser_error
            }
            return(list(summary = summary, operations = records))
          }
          methods <- c(
            'get',
            'post',
            'put',
            'patch',
            'delete',
            'head',
            'options',
            'trace'
          )
          if (is.list(doc) && !is.null(names(doc)) && is.list(doc$paths)) {
            summary$declared <- sum(vapply(
              doc$paths,
              function(x) sum(names(x) %in% methods),
              integer(1)
            ))
            summary$path_refs <- sum(vapply(
              doc$paths,
              function(x) '$ref' %in% names(x),
              logical(1)
            ))
          }
          warnings <- character()
          parsed <- tryCatch(
            withCallingHandlers(
              specmill::read_operations(input$prepared),
              warning = function(w) {
                warnings <<- unique(c(warnings, clean(w)))
                invokeRestart('muffleWarning')
              }
            ),
            error = function(e) {
              summary$parser_error <<- clean(e)
              NULL
            }
          )
          summary$warnings <- paste(warnings, collapse = '; ')
          if (native) {
            summary$raw_error <- summary$parser_error
          }
          if (is.null(parsed)) {
            return(list(summary = summary, operations = records))
          }
          summary$selected <- length(parsed$operations)
          summary$diagnosed <- length(parsed$diagnostics)
          for (d in parsed$diagnostics) {
            records[[length(records) + 1L]] <- data.frame(
              file = input$file,
              key = d$key,
              stage = 'parser',
              classification = if (is.null(d$classification)) {
                ''
              } else {
                d$classification
              },
              code = if (is.null(d$code)) '' else d$code,
              reason = d$reason
            )
          }
          for (op in parsed$operations) {
            stage <- 'render'
            error <- tryCatch(
              {
                code <- specmill::render_operation(
                  op,
                  list(helper = 'request_helper')
                )
                context <- new.env(parent = baseenv())
                context$request_helper <- function(...) list(...)
                context$run_hook <- function(...) NULL
                eval(parse(text = code), context)
                summary$rendered <- summary$rendered + 1L
                stage <- 'fixture'
                values <- specmill::operation_fixtures(list(op))[[1L]]
                summary$fixtures <- summary$fixtures + 1L
                stage <- 'invoke'
                do.call(context[[op$name]], values)
                summary$invoked <- summary$invoked + 1L
                ''
              },
              error = clean
            )
            records[[length(records) + 1L]] <- data.frame(
              file = input$file,
              key = paste(op$method, op$route),
              stage = if (nzchar(error)) stage else 'passed',
              classification = '',
              code = '',
              reason = error
            )
          }
          list(summary = summary, operations = records)
        },
        args = list(input = input, native = !is.null(native_root)),
        timeout = 180
      ),
      error = function(e) {
        list(
          summary = list(file = input$file, worker_error = conditionMessage(e)),
          operations = list()
        )
      }
    )
    summaries[[i]] <- result$summary
    operations <- c(operations, result$operations)
    # Keep completed inputs reviewable even if a later large schema fails.
    write.csv(
      dplyr::bind_rows(summaries),
      file.path(output, 'schemas.csv'),
      row.names = FALSE
    )
    write.csv(
      dplyr::bind_rows(operations),
      file.path(output, 'operations.csv'),
      row.names = FALSE
    )
  }
  stopifnot(
    identical(before, tools::md5sum(inputs$source)),
    length(summaries) == nrow(inputs)
  )
  write.csv(
    inputs[c('file', 'tier', 'stresses', 'url', 'sha256', 'version')],
    file.path(output, 'sources.csv'),
    row.names = FALSE
  )
  if (is.null(native_root) && report) {
    report_testing_specs(prepared, output)
  }
  invisible(list(
    schemas = dplyr::bind_rows(summaries),
    operations = dplyr::bind_rows(operations)
  ))
}

report_testing_specs <- function(
  prepared = '.docs-lib/additional-json',
  output = 'dev/audits/additional-schemas'
) {
  inputs <- read.csv(
    file.path(prepared, 'inputs.csv'),
    colClasses = 'character'
  )
  schemas <- read.csv(
    file.path(output, 'schemas.csv'),
    stringsAsFactors = FALSE
  )
  operations <- read.csv(
    file.path(output, 'operations.csv'),
    stringsAsFactors = FALSE
  )
  caveats <- list()
  methods <- c(
    'get',
    'post',
    'put',
    'patch',
    'delete',
    'head',
    'options',
    'trace'
  )
  for (i in seq_len(nrow(inputs))) {
    if (nzchar(inputs$conversion_error[[i]])) {
      next
    }
    doc <- jsonlite::read_json(inputs$prepared[[i]])
    if (!is.list(doc) || is.null(names(doc))) {
      next
    }
    for (path in names(doc$paths)) {
      item <- doc$paths[[path]]
      for (method in intersect(names(item), methods)) {
        ref <- item[[method]][['$ref']]
        if (is.character(ref) && length(ref) == 1L) {
          caveats[[length(caveats) + 1L]] <- data.frame(
            file = inputs$file[[i]],
            key = paste(toupper(method), path),
            reason = 'Operation reference not resolved; smoke pass is not coverage',
            reference = ref
          )
        }
      }
    }
  }
  caveats <- dplyr::bind_rows(caveats)
  write.csv(
    caveats,
    file.path(output, 'coverage-caveats.csv'),
    row.names = FALSE
  )
  id <- function(x) paste(x$file, x$key)
  credible <- operations$stage == 'passed' & !id(operations) %in% id(caveats)
  stopifnot(
    nrow(schemas) == 33L,
    sum(schemas$selected) == nrow(operations[operations$stage != 'parser', ]),
    sum(schemas$diagnosed) == sum(operations$stage == 'parser'),
    sum(credible) == 1524L,
    nrow(caveats) == 659L
  )
  rows <- vapply(
    seq_len(nrow(schemas)),
    function(i) {
      x <- schemas[i, ]
      covered <- sum(credible & operations$file == x$file)
      label <- paste0(basename(x$file), ' (', inputs$stresses[[i]], ')')
      note <- if (nzchar(x$parser_error)) {
        if (x$tier == 'json-schema') {
          'Not an OpenAPI document'
        } else {
          x$parser_error
        }
      } else if (x$file %in% caveats$file) {
        'Unresolved operation refs: all apparent passes uncovered'
      } else {
        ''
      }
      paste0(
        '| ',
        label,
        ' | ',
        x$declared,
        ' | ',
        x$selected,
        ' | ',
        x$diagnosed,
        ' | ',
        covered,
        ' | ',
        note,
        ' |'
      )
    },
    character(1)
  )
  writeLines(
    c(
      '# Additional schema corpus: 2026-09-11',
      '',
      'Tested installed specmill. The historical baseline was recorded at c50f5ea. All 33 primary downloads were exercised independently,',
      'with all HTTP methods enabled and no proving-ground exclusions. Source hashes were unchanged.',
      'The active 27-API configuration and its 328/205/15 baseline were not modified.',
      '',
      '## Results',
      '',
      '**1,524 operations passed parsing, rendering, fixture generation, and wrapper invocation',
      'without an unresolved operation-level reference.** These are offline smoke passes, not',
      'verified service contracts or complete response-schema support.',
      '',
      'After conversion, parsing selected 2,186 operations and diagnosed 660. All selected wrappers rendered;',
      '2,185 produced fixtures and 2,183 invoked a recording helper successfully. Of those, 659',
      'DigitalOcean wrappers have unresolved operation references and are excluded from the 1,524.',
      'Two GitHub documents aborted entirely, hiding 2,458 declared operations from operation-level',
      'results. OpenAPI 3.2 (four operations), a webhook-only document, and four JSON Schema test',
      'arrays were rejected at document level. The latter arrays are not OpenAPI inputs.',
      '',
      '| Input | Declared | Selected | Diagnosed | Smoke passes, excluding unresolved operation refs | Document caveat |',
      '| --- | ---: | ---: | ---: | ---: | --- |',
      rows,
      '',
      '## Actionable findings',
      '',
      '1. **YAML ingestion:** schemas.csv records direct-source errors for the installed package. The table uses',
      '   temporary JSON conversions with installed ruamel.yaml in YAML 1.2 mode. No bundling,',
      '   schema repairs, example-derived types, name overrides, or API requests were applied.',
      '2. **DigitalOcean is a false positive:** all 659 operations contain `$ref` to a local',
      '   operation file. Those references are ignored, producing wrappers with no referenced',
      '   inputs. Example: `GET /v2/1-clicks` -> `resources/1-clicks/oneClicks_list.yml`.',
      '   These unbundled inputs require preprocessing or an explicit diagnostic; their smoke',
      '   success must not be reported as supported operation contracts.',
      '3. **Whole-document GitHub failures:** the 3.0 description aborts at',
      '   `POST /orgs/{org}/{security_product}/{enablement}` with a missing logical value;',
      '   the 3.1 description aborts at `/app` with a length-greater-than-one type condition.',
      '   Exact native errors are retained in schemas.csv. No partial results survive.',
      '4. **Base-function name collision:** both allOf examples use operationId `list` for',
      '   `GET /person/display/{personId}`. The generated `list <- function(...)` calls bare',
      '   `list(...)` internally, recursively invoking itself. Reproduced with a helper that',
      '   explicitly calls `base::list`, confirming the generated wrapper is responsible.',
      '5. **Fixture gap:** Box `GET /files/{file_id}/thumbnail.{extension}` renders but fixture',
      '   generation fails. Integer height/width parameters require a minimum of 32; the',
      '   source supplies parameter-level examples. A reviewed override is requested.',
      '6. **Media and schema gaps:** 615 body-media diagnostics (594 Stripe operations), 34',
      '   body-composition diagnostics, seven recursive-reference diagnostics (Kubernetes),',
      '   two external-reference diagnostics, one invalid-type diagnostic, and one unsupported',
      '   parameter-array-items diagnostic. Exact operation keys and reasons are in operations.csv.',
      '',
      'Passing oneOf/discriminator examples does not establish composition support: many put',
      'the complicated schemas in responses or unused components. Callback/link examples only',
      'exercise their ordinary path operations; callback execution and link traversal are untested.',
      'The four AMOS defects belong to the existing corpus and remain separate under #16.',
      '',
      '## Reproduce',
      '',
      '```powershell',
      'python dev/prepare_testing_specs.py C:/Users/sxthi/Documents/specmill-testing/additional-schemas .docs-lib/additional-json',
      '```',
      '',
      '```r',
      "source('dev/audit_testing_specs.R')",
      'audit_testing_specs()',
      '```',
      '',
      'Each schema runs in an isolated R process with a 180-second timeout. Generated wrappers',
      'execute against a recording helper, so this run does not test HTTP encoding, real',
      'authentication, remote responses, or client-package initialization. The existing #8',
      'localhost transport suite covers its supported encodings separately. No package runtime',
      'code was changed here; the audit itself checks count consistency and source preservation.',
      '',
      '[Schema results](schemas.csv), [operation results](operations.csv),',
      '[unresolved operation references](coverage-caveats.csv), [source URLs and hashes](sources.csv).'
    ),
    file.path(output, 'RESULTS.md')
  )
  invisible(caveats)
}
