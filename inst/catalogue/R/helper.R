.calls <- new.env(parent = emptyenv())
.calls$values <- list()
captured <- function() .calls$values
clear_calls <- function() { .calls$values <- list(); invisible(NULL) }
catalogue_request <- function(method, path, path_params, query, body) {
  .calls$values[[length(.calls$values) + 1L]] <- list(method = method, path = path,
    path_params = path_params, query = query, body = body)
  list(data = 'ok')
}
normalize_input <- function(state) {
  state$params$item_id <- trimws(state$params$item_id)
  state
}
extract_output <- function(state) state$result$data
hook_config <- list(get_item = list(pre_request = 'normalize_input', post_response = 'extract_output'))
run_hook <- function(fn, stage, state) {
  for (name in hook_config[[fn]][[stage]]) state <- get(name, envir = environment(run_hook), inherits = FALSE)(state)
  state
}
wire_request <- function(method, path, path_params, query, body) {
  for (name in names(path_params)) path <- gsub(paste0('{', name, '}'),
    utils::URLencode(path_params[[name]], reserved = TRUE), path, fixed = TRUE)
  request <- httr2::request('https://catalogue.invalid')
  request <- httr2::req_method(request, method)
  request <- do.call(httr2::req_url_query, c(list(request), query))
  suffix <- if (grepl('?', request$url, fixed = TRUE)) sub('^[^?]*', '', request$url) else ''
  request <- httr2::req_url(request, paste0('https://catalogue.invalid', path, suffix))
  if (!is.null(body)) request <- httr2::req_body_json(request, body)
  request
}
