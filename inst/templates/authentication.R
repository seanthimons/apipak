# Generated with specmill; do not edit by hand.

#' Read a configured API credential
#' @param scheme Security scheme name; optional when only one is configured.
#' @return Credential string. Treat this value as a secret.
#' @export
api_token <- function(scheme = NULL) {
  envvars <- AUTH_ENVVARS
  if (is.null(scheme) && length(envvars) == 1L) scheme <- names(envvars)[[1L]]
  if (!is.character(scheme) || length(scheme) != 1L || is.na(scheme) || !scheme %in% names(envvars)) {
    stop('Choose a configured credential scheme: ', paste(names(envvars), collapse = ', '), call. = FALSE)
  }
  value <- Sys.getenv(envvars[[scheme]], unset = '')
  if (!nzchar(trimws(value))) {
    stop('Missing credential for ', scheme, '. Set ', envvars[[scheme]],
      ' or call set_api_token(token, scheme = ', dQuote(scheme), ').', call. = FALSE)
  }
  if (grepl('[\r\n]', value)) stop('Credential contains a line break', call. = FALSE)
  value
}

#' Set an API credential for this session or save it for future sessions
#' @param token Credential supplied by the user. Never put it in tracked files.
#' @param scheme Security scheme name; optional when only one is configured.
#' @param persist Save to a user environment file when TRUE. Defaults to session only.
#' @param file Environment file used when persist is TRUE. Defaults to R_ENVIRON_USER
#'   when set, otherwise the user home .Renviron. A project .Renviron may take precedence.
#' @return Invisibly NULL. The token is never printed or returned.
#' @details Saved credentials are plain text. Existing unrelated lines are preserved.
#' No environment file is read or written when the package loads.
#' @export
set_api_token <- function(token, scheme = NULL, persist = FALSE,
  file = Sys.getenv('R_ENVIRON_USER', unset = path.expand('~/.Renviron'))) {
  envvars <- AUTH_ENVVARS
  if (is.null(scheme) && length(envvars) == 1L) scheme <- names(envvars)[[1L]]
  if (!is.character(scheme) || length(scheme) != 1L || is.na(scheme) || !scheme %in% names(envvars)) {
    stop('Choose a configured credential scheme: ', paste(names(envvars), collapse = ', '), call. = FALSE)
  }
  if (!is.character(token) || length(token) != 1L || is.na(token) ||
      !nzchar(trimws(token)) || grepl('[\r\n]', token)) stop('Supply one nonempty token without line breaks', call. = FALSE)
  if (!is.logical(persist) || length(persist) != 1L || is.na(persist)) stop('persist must be TRUE or FALSE')
  envvar <- envvars[[scheme]]
  if (persist) {
    # Reject values that R's startup-file expansion could change; session use is unrestricted.
    if (grepl('["\'\\\\]', token) || grepl('${', token, fixed = TRUE) || nchar(token, type = 'bytes') > 90000L) {
      stop('Token cannot be safely saved in .Renviron; use persist = FALSE', call. = FALSE)
    }
    if (!is.character(file) || length(file) != 1L || is.na(file) || !nzchar(file)) stop('Supply an environment file path')
    file <- path.expand(file)
    existing <- file.exists(file)
    before <- if (existing) readLines(file, warn = FALSE) else character()
    lines <- before[!grepl(paste0('^[[:space:]]*', envvar, '[[:space:]]*='), before)]
    lines <- c(lines, paste0(envvar, '="', token, '"'))
    staged <- tempfile('.api-env-', tmpdir = dirname(file))
    backup <- tempfile('.api-env-backup-', tmpdir = dirname(file))
    on.exit(unlink(c(staged, backup)), add = TRUE)
    writeLines(lines, staged, useBytes = TRUE)
    Sys.chmod(staged, '0600')
    if (existing && !file.copy(file, backup)) stop('Cannot back up environment file')
    if (existing && !identical(before, readLines(file, warn = FALSE))) stop('Environment file changed; retry')
    if (!file.copy(staged, file, overwrite = TRUE)) {
      if (existing) file.copy(backup, file, overwrite = TRUE)
      stop('Cannot save environment file', call. = FALSE)
    }
    if (!existing) Sys.chmod(file, '0600')
    message('Credential saved to ', file, '. It is also available in this R session.')
  }
  do.call(Sys.setenv, stats::setNames(list(token), envvar))
  invisible(NULL)
}

api_auth <- function(request, requirements) {
  if (!length(requirements) || any(vapply(requirements, function(x) !length(x), logical(1)))) return(request)
  available <- function(scheme) {
    scheme$type %in% c('apiKey', 'bearer') && nzchar(trimws(Sys.getenv(scheme$envvar, unset = '')))
  }
  for (requirement in requirements) {
    if (!all(vapply(requirement, available, logical(1)))) next
    for (scheme in requirement) {
      token <- api_token(scheme$scheme)
      if (scheme$type == 'bearer') {
        request <- httr2::req_auth_bearer_token(request, token)
      } else if (scheme$location == 'header') {
        request <- do.call(httr2::req_headers, c(list(request, .redact = scheme$name), stats::setNames(list(token), scheme$name)))
      } else if (scheme$location == 'query') {
        request <- do.call(httr2::req_url_query, c(list(request), stats::setNames(list(token), scheme$name)))
      } else {
        cookie <- paste0(utils::URLencode(scheme$name, reserved = TRUE), '=', utils::URLencode(token, reserved = TRUE))
        prior <- request$headers[['Cookie']]
        if (!is.null(prior)) cookie <- paste(prior, cookie, sep = '; ')
        request <- httr2::req_headers(request, Cookie = cookie, .redact = 'Cookie')
      }
    }
    return(request)
  }
  choices <- vapply(requirements, function(requirement) paste(vapply(requirement, function(scheme) {
    if (scheme$type %in% c('apiKey', 'bearer')) paste0(scheme$scheme, ' (', scheme$envvar, ')')
    else paste0(scheme$scheme, ' [', scheme$type, ' authentication is not implemented; OAuth login/refresh is deferred]')
  }, character(1)), collapse = ' + '), character(1))
  stop('Authentication required. Configure one complete option: ', paste(choices, collapse = ' OR '),
    '. Use set_api_token(token, scheme = "scheme_name") for API keys or bearer tokens.', call. = FALSE)
}
