comptox_contract_probe <- function(
  root,
  support = 'evidence/schema-support.rds',
  mappings = 'evidence/interface-probe.rds',
  output = 'evidence/contract-probe.rds',
  expected_count = 152L
) {
  root <- normalizePath(root, winslash = '/', mustWork = TRUE)
  Sys.setenv(COMPTOXR_CRAN_SAFE_TESTS = 'true', NOT_CRAN = 'false')
  Sys.unsetenv(c('ctx_api_key', 'GITHUB_OUTPUT'))
  pkgload::load_all(root, quiet = TRUE)
  namespace <- asNamespace('ComptoxR')
  fixtures <- new.env(parent = baseenv())
  sys.source(
    file.path(root, 'tests/testthat/helper-generated-contracts.R'),
    fixtures
  )
  sys.source(file.path(root, 'dev/test_generation/03_test_values.R'), fixtures)
  sys.source(
    file.path(root, 'tests/testthat/helper-descriptor-contracts.R'),
    fixtures
  )
  callbacks <- new.env(parent = emptyenv())
  callbacks$batch_limit_1000 <- function(operation) {
    quote(as.numeric(Sys.getenv('batch_limit', '1000')))
  }
  callbacks$batch_limit_100 <- function(operation) {
    quote(as.numeric(Sys.getenv('batch_limit', '100')))
  }
  callbacks$lowercase_sort <- function(operation) {
    quote(
      if (!is.null(params$sort)) tolower(as.character(params$sort)) else NULL
    )
  }
  project <- apipak::load_project(root, callbacks = callbacks)
  schemas <- readRDS(support)
  operations <- do.call(
    c,
    unname(lapply(schemas, function(x) {
      c(x$operations, x$unsupported_operations)
    }))
  )
  mappings <- readRDS(mappings)
  frozen <- readRDS('evidence/baseline/public-contracts.rds')
  original_definitions <- list()
  for (record in frozen) {
    for (definition in record$definitions) {
      original_definitions[[definition$name]] <- definition$code
    }
  }
  captured <- list()
  mock <- function(...) {
    arguments <- list(...)
    captured[[length(captured) + 1L]] <<- arguments
    if (
      identical(arguments$server, 'epi_burl') &&
        identical(arguments$endpoint, 'search')
    ) {
      return(list(list(name = 'Water', smiles = 'O', cas = '7732-18-5')))
    }
    if (
      arguments$endpoint %in%
        c('descriptors', 'padel', 'mordred', 'rdkit', 'webtest')
    ) {
      return(fixtures$descriptor_contract_response(
        records = list(fixtures$descriptor_contract_record()),
        headers = c('a', 'b')
      ))
    }
    if (identical(arguments$endpoint, 'webtest/predict')) {
      return(list(
        chemicals = list(fixtures$webtest_contract_prediction(
          chemical_id = 'CCO',
          smiles = 'CCO'
        ))
      ))
    }
    fixtures$generated_contract_response(...)
  }
  testthat::local_mocked_bindings(
    generic_request = mock,
    generic_chemi_request = mock,
    chemi_resolver_lookup = fixtures$generated_contract_resolver_lookup,
    chemi_resolver_lookup_bulk = fixtures$generated_contract_resolver_lookup_bulk,
    .package = 'ComptoxR'
  )
  results <- list()
  file <- tempfile(fileext = '.yml')
  for (operation in operations) {
    mapping <- mappings[[operation$id]]
    if (is.null(mapping) || mapping$status != 'mapped request shape') {
      next
    }
    results[[operation$id]] <- tryCatch(
      {
        service <- project$services[[
          if (operation$service == 'ct') 'ctx' else operation$service
        ]]
        yaml::write_yaml(mapping$settings, file, precision = 17)
        service$operations[[operation$key]] <- getFromNamespace(
          'read_config_yaml',
          'apipak'
        )(file)
        configured <- getFromNamespace('configure_operation', 'apipak')(
          operation,
          service
        )
        context <- new.env(parent = namespace)
        eval(
          parse(
            text = apipak::render_operation(
              configured$operation,
              configured$spec
            )
          ),
          context
        )
        candidate <- context[[operation$name]]
        original <- eval(
          parse(text = original_definitions[[operation$name]])[[1L]],
          namespace
        )
        if (!identical(formals(candidate), formals(original))) {
          stop(
            'Public formal mismatch: ',
            paste(deparse(formals(candidate)), collapse = ' '),
            ' / ',
            paste(deparse(formals(original)), collapse = ' ')
          )
        }
        inputs <- list()
        for (name in names(mapping$settings$inputs)) {
          if (isTRUE(mapping$settings$inputs[[name]]$required)) {
            inputs[[name]] <- fixtures$tg_value_for_param(name)
          }
        }
        for (name in intersect(
          names(formals(original)),
          c('resolve', 'cache')
        )) {
          inputs[[name]] <- FALSE
        }
        if (
          operation$name %in% c('chemi_descriptors', 'chemi_descriptors_bulk')
        ) {
          inputs$type <- 'padel'
        }
        if (operation$name == 'chemi_webtest_predict') {
          inputs$endpoint <- 'LC50'
        }
        if (operation$name == 'chemi_webtest_predict_bulk') {
          inputs$endpoints <- 'LC50'
        }
        if (
          operation$name %in%
            c('chemi_opera_bulk', 'chemi_predictor_models_predict_bulk')
        ) {
          inputs$smiles <- list('CCO')
        }
        if (operation$name == 'chemi_search') {
          inputs$query <- 'CCO'
        }
        invoke <- function(fn) {
          captured <<- list()
          value <- tryCatch(
            suppressMessages(suppressWarnings(do.call(fn, inputs))),
            error = identity
          )
          list(value = value, calls = captured)
        }
        before <- invoke(original)
        if (!inherits(before$value, 'error')) {
          after <- invoke(candidate)
          if (inherits(after$value, 'error')) {
            stop(
              'Candidate failed after successful baseline: ',
              conditionMessage(after$value)
            )
          }
          if (!identical(before, after)) {
            stop(
              'Behavior differs: ',
              paste(all.equal(before, after), collapse = '; ')
            )
          }
          negatives <- list()
          normal_inputs <- inputs
          for (name in names(mapping$settings$inputs)) {
            if (!isTRUE(mapping$settings$inputs[[name]]$required)) {
              next
            }
            inputs <- normal_inputs
            inputs[name] <- list(NULL)
            null_before <- invoke(original)
            null_after <- invoke(candidate)
            before_error <- inherits(null_before$value, 'error')
            after_error <- inherits(null_after$value, 'error')
            if (
              before_error &&
                after_error &&
                identical(class(null_before$value), class(null_after$value)) &&
                identical(null_before$calls, null_after$calls)
            ) {
              negatives[[name]] <- 'same rejection'
            } else if (
              !before_error &&
                !after_error &&
                identical(null_before, null_after)
            ) {
              negatives[[name]] <- 'same successful NULL behavior'
            } else {
              stop(
                'NULL behavior differs for ',
                name,
                ': baseline error=',
                before_error,
                ', candidate error=',
                after_error
              )
            }
          }
          inputs <- normal_inputs
          return_value <- list(
            status = 'successful parity',
            name = operation$name,
            inputs = inputs,
            request = before$calls,
            result = before$value,
            null_inputs = negatives
          )
        } else {
          return_value <- list(
            status = 'baseline fixture error',
            name = operation$name,
            message = conditionMessage(before$value)
          )
        }
        return_value
      },
      error = function(e) {
        list(
          status = 'candidate mismatch',
          name = operation$name,
          message = conditionMessage(e)
        )
      }
    )
  }
  saveRDS(results, output)
  print(table(vapply(results, `[[`, character(1), 'status')))
  failures <- Filter(function(x) x$status != 'successful parity', results)
  for (record in failures) {
    cat(record$name, ': ', record$status, ': ', record$message, '\n', sep = '')
  }
  stopifnot(length(results) == expected_count, !length(failures))
  invisible(results)
}
if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  if ('--chemi' %in% args) {
    comptox_contract_probe(
      args[[1L]],
      mappings = 'evidence/chemi-interface-probe.rds',
      output = 'evidence/chemi-contract-probe.rds',
      expected_count = 186L
    )
  } else {
    comptox_contract_probe(args[[1L]])
  }
}
