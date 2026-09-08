fixture_value <- function(schema, override = NULL) {
  value <- override %or%
    schema$example %or%
    schema$default %or%
    schema$enum[[1L]]
  if (is.null(value)) {
    value <- switch(
      schema$type,
      string = 'example',
      integer = 1L,
      number = 1,
      boolean = TRUE
    )
  }
  valid <- length(value) == 1L &&
    !is.na(value) &&
    switch(
      schema$type,
      string = is.character(value),
      integer = is.numeric(value) && value == trunc(value),
      number = is.numeric(value) && is.finite(value),
      boolean = is.logical(value),
      FALSE
    )
  if (valid && !is.null(schema$enum)) {
    valid <- value %in% unlist(schema$enum)
  }
  if (valid && !is.null(schema$minimum)) {
    valid <- value >= schema$minimum
  }
  if (valid && !is.null(schema$maximum)) {
    valid <- value <= schema$maximum
  }
  if (valid && !is.null(schema$minLength)) {
    valid <- nchar(value) >= schema$minLength
  }
  if (valid && !is.null(schema$maxLength)) {
    valid <- nchar(value) <= schema$maxLength
  }
  if (valid && !is.null(schema$pattern)) {
    valid <- grepl(schema$pattern, value, perl = TRUE)
  }
  if (!isTRUE(valid)) {
    stop('No valid fixture: supply a reviewed override', call. = FALSE)
  }
  value
}

operation_fixtures <- function(operations, overrides = list()) {
  lapply(operations, function(op) {
    inputs <- setNames(
      lapply(op$parameters, function(p) {
        fixture_value(p$schema, overrides[[op$name]][[p$name]])
      }),
      parameter_names(op$parameters)
    )
    if (!is.null(op$body)) {
      inputs$body <- body_fixture(op$body, overrides[[op$name]]$body)
    }
    inputs
  })
}
