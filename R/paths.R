# ==============================================================================
# Path Manipulation
# ==============================================================================

#' Strip curly parameter placeholders from endpoint paths
#'
#' This utility removes `{}` parameter tokens from endpoint strings and optionally
#' normalises leading and trailing slashes.
#' @param paths Character vector of endpoint paths that may contain tokens such as `{id}`.
#' @param keep_trailing_slash Logical; if FALSE the trailing slash is removed.
#' @param leading_slash Character, one of "keep", "ensure", "remove" to control the leading slash.
#' @return A character vector of cleaned endpoint paths.
#' @examples
#' strip_curly_params(c("/hazard/{id}/"))
#' @export
strip_curly_params <- function(paths, keep_trailing_slash = TRUE, leading_slash = c("keep", "ensure", "remove")) {
  leading_slash <- match.arg(leading_slash)

  # 1) Remove {param} tokens
  out <- stringr::str_replace_all(paths, "\\{[^}]+\\}", "")

  # 2) Collapse duplicate slashes
  out <- stringr::str_replace_all(out, "/{2,}", "/")

  # 3) Trailing slash handling
  if (!keep_trailing_slash) {
    out <- stringr::str_remove(out, "/$")
  }

  # 4) Leading slash handling
  if (leading_slash == "ensure") {
    out <- ifelse(stringr::str_starts(out, "/"), out, paste0("/", out))
  } else if (leading_slash == "remove") {
    # Remove any leading slash(es)
    out <- stringr::str_remove(out, "^/+")
  } # "keep" leaves as-is

  out
}
