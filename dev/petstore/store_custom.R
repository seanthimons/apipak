# Select JSON from the service's JSON/XML/form alternatives.
#' Create an order using JSON
#' @param body Named list describing the order; NULL omits the body.
#' @return Decoded response from the service.
#' @family store endpoints
#' @export
store_order_create <- function(body = NULL) {
  api_request('POST', '/store/order', list(), list(), body)
}
