parameter_names <- function(parameters) {
  result <- make.names(vapply(
    parameters,
    function(p) p$public_name %or% p$name,
    character(1)
  ))
  reserved <- grepl('^\\.\\.([0-9]+|\\.)$', result)
  result[reserved] <- paste0('value', result[reserved])
  make.unique(result)
}
