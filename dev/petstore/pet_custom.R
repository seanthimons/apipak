# Client-owned implementations for media types the native parser rejects.
#' Create a pet using JSON
#' @param body Named list with name and photoUrls; arrays use unnamed lists.
#' @return Decoded response from the service.
#' @family pet endpoints
#' @export
pet_create <- function(body) {
  api_request('POST', '/pet', list(), list(), body)
}

#' Update a pet using JSON
#' @param body Named list describing the pet, including its id.
#' @return Decoded response from the service.
#' @family pet endpoints
#' @export
pet_update <- function(body) {
  api_request('PUT', '/pet', list(), list(), body)
}

#' Upload raw image bytes for a pet
#' @param pet_id Pet identifier.
#' @param image Raw image bytes; NULL omits the body.
#' @param metadata Optional image metadata.
#' @return Decoded response from the service.
#' @family pet endpoints
#' @export
pet_upload_image <- function(pet_id, image = NULL, metadata = NULL) {
  if (!is.null(image) && !is.raw(image)) {
    stop('image must be a raw vector')
  }
  api_request(
    'POST',
    '/pet/{petId}/uploadImage',
    list(petId = pet_id),
    list(additionalMetadata = metadata),
    image,
    raw_body = TRUE
  )
}
