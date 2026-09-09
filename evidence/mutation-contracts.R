# Independent oracles must reject six faults in otherwise executable generated code.
mutation_contracts <- function() {
  operations <- apipak::read_operations(system.file('catalogue/schema.json', package = 'apipak'))$operations
  spec <- list(helper = 'capture', hooks = list(get_item = list(pre_request = 'before', post_response = 'after')))
  compile <- function(op) eval(parse(text = apipak::render_operation(op, spec))[[1L]][[3L]], baseenv())
  original <- compile(operations$get_item)
  expected <- list(method = 'GET', path = '/items/{item_id}', path_params = list(item_id = 'x'), query = list(language = 'fr'), body = NULL)
  verify <- function(fn, inputs = list(item_id = 'x', language = 'fr'), request = expected,
    order = c('pre_request', 'request', 'post_response')) {
    runtime <- new.env(parent = baseenv())
    runtime$events <- character()
    runtime$seen <- NULL
    runtime$capture <- function(...) {
      runtime$events <- c(runtime$events, 'request')
      runtime$seen <- list(...)
      list(data = 1L)
    }
    runtime$run_hook <- function(name, stage, state) {
      runtime$events <- c(runtime$events, stage)
      if (stage == 'post_response') state$result else state
    }
    environment(fn) <- runtime
    result <- do.call(fn, inputs)
    stopifnot(identical(result, list(data = 1L)), identical(runtime$seen, request), identical(runtime$events, order))
  }
  rejected <- function(expr) inherits(tryCatch({force(expr); NULL}, error = identity), 'error')
  verify(original)
  wrong_method <- operations$get_item
  wrong_method$method <- 'POST'
  wrong_location <- operations$get_item
  wrong_location$parameters[[1L]]$location <- 'query'
  statements <- as.list(body(original))
  text <- vapply(statements, function(x) paste(deparse(x), collapse = ' '), character(1))
  no_presence <- original
  body(no_presence) <- as.call(statements[!grepl('Required input:', text, fixed = TRUE)])
  wrong_order <- original
  pre <- grep('"pre_request"', text, fixed = TRUE)
  request_index <- grep('capture(', text, fixed = TRUE)
  block <- seq.int(pre, request_index - 1L)
  reordered <- statements[-block]
  after_request <- request_index - length(block)
  body(wrong_order) <- as.call(append(reordered, statements[block], after = after_request))
  after_error <- original
  body(after_error) <- as.call(append(statements, list(quote(stop('fault after correct helper call'))), after = request_index))
  create <- compile(operations$create_item)
  create_request <- list(method = 'POST', path = '/items', path_params = list(), query = list(), body = list(title = 'expected'))
  verify(create, list(body = list(title = 'expected')), create_request, 'request')
  results <- c(
    wrong_method = rejected(verify(compile(wrong_method))),
    wrong_location = rejected(verify(compile(wrong_location))),
    wrong_body = rejected(verify(create, list(body = list(title = 'wrong')), create_request, 'request')),
    missing_required = rejected(verify(original, list(item_id = NULL, language = 'fr'))) &&
      !rejected(verify(no_presence, list(item_id = NULL, language = 'fr'),
        modifyList(expected, list(path_params = list(item_id = NULL)), keep.null = TRUE))),
    wrong_hook_order = rejected(verify(wrong_order)),
    error_after_helper = rejected(verify(after_error))
  )
  stopifnot(all(results))
  print(results)
  invisible(results)
}
if (sys.nframe() == 0L) mutation_contracts()
