# Client-owned transport: JSON, repeated query keys, headers, and raw uploads.
api_request <- function(
  method,
  path,
  path_params,
  query,
  body,
  headers = list(),
  raw_body = FALSE
) {
  for (name in names(path_params)) {
    path <- gsub(
      paste0('{', name, '}'),
      utils::URLencode(as.character(path_params[[name]]), reserved = TRUE),
      path,
      fixed = TRUE
    )
  }
  base_url <- getOption(
    'petstoretrial.base_url',
    'https://petstore3.swagger.io/api/v3'
  )
  request <- httr2::request(paste0(sub('/+$', '', base_url), path))
  request <- httr2::req_headers(request, Accept = 'application/json')
  query <- Filter(Negate(is.null), query)
  if (length(query)) {
    request <- do.call(
      httr2::req_url_query,
      c(list(request), query, list(.multi = 'explode'))
    )
  }
  if (length(headers)) {
    request <- do.call(httr2::req_headers, c(list(request), headers))
  }
  if (!is.null(body)) {
    request <- if (raw_body) {
      httr2::req_body_raw(request, body, type = 'application/octet-stream')
    } else {
      httr2::req_body_json(request, body, auto_unbox = TRUE, null = 'null')
    }
  }
  request <- httr2::req_method(request, method)
  response <- httr2::req_perform(httr2::req_timeout(request, 30))
  if (!httr2::resp_has_body(response)) {
    return(NULL)
  }
  bytes <- httr2::resp_body_raw(response)
  if (!length(bytes)) {
    return(NULL)
  }
  media <- httr2::resp_header(response, 'content-type')
  if (is.null(media)) {
    media <- ''
  }
  media <- tolower(sub(';.*$', '', media))
  if (grepl('(/json|\\+json)$', media)) {
    return(jsonlite::fromJSON(
      httr2::resp_body_string(response),
      simplifyVector = FALSE
    ))
  }
  if (startsWith(media, 'text/') || media == 'image/svg+xml') {
    return(httr2::resp_body_string(response))
  }
  bytes
}
