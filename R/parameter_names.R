parameter_names <- function(parameters) {
  result <- make.names(vapply(parameters, `[[`, character(1), 'name'))
  reserved <- grepl('^\\.\\.([0-9]+|\\.)$', result)
  result[reserved] <- paste0('value', result[reserved])
  make.unique(result)
}
