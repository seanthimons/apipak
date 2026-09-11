# Select JSON from the service's JSON/XML/form alternatives.
#' Create a user using JSON
#' @param body Named list describing the user; NULL omits the body.
#' @return Decoded response from the service.
#' @family user endpoints
#' @export
user_create <- function(body = NULL) {
  api_request('POST', '/user', list(), list(), body)
}

#' Update a user using JSON
#' @param username User identifier.
#' @param body Named list describing the user; NULL omits the body.
#' @return Decoded response from the service.
#' @family user endpoints
#' @export
user_update <- function(username, body = NULL) {
  api_request(
    'PUT',
    '/user/{username}',
    list(username = username),
    list(),
    body
  )
}
