request_shapes <- function(baseline, output) {
  contracts <- readRDS(file.path(baseline, 'public-contracts.rds'))
  rows <- list()
  calls <- list()
  for (file in names(contracts)) {
    record <- contracts[[file]]
    for (definition in record$definitions) {
      expression <- parse(text = definition$code)[[1L]]
      visit <- function(node) {
        if (missing(node) || !is.call(node)) return(invisible(NULL))
        if (record$ownership$status == 'selected' && is.symbol(node[[1L]])) {
          calls[[length(calls) + 1L]] <<- data.frame(function_name = definition$name,
            call = as.character(node[[1L]]), expression = paste(deparse(node), collapse = '\n'))
        }
        if (is.symbol(node[[1L]]) && as.character(node[[1L]]) %in% c('generic_request', 'generic_chemi_request')) {
          arguments <- as.list(node)[-1L]
          for (i in seq_along(arguments)) {
            rows[[length(rows) + 1L]] <<- data.frame(file = file, function_name = definition$name,
              ownership = record$ownership$status, helper = as.character(node[[1L]]),
              argument = if (is.null(names(arguments)) || !nzchar(names(arguments)[[i]])) '<positional>' else names(arguments)[[i]],
              expression = paste(deparse(arguments[[i]]), collapse = '\n'))
          }
        }
        for (child in as.list(node)[-1L]) visit(child)
      }
      visit(expression)
    }
  }
  rows <- do.call(rbind, rows)
  write.csv(rows, file.path(output, 'request-shapes.csv'), row.names = FALSE)
  calls <- do.call(rbind, calls)
  write.csv(calls, file.path(output, 'wrapper-calls.csv'), row.names = FALSE)
  print(sort(table(calls$call), decreasing = TRUE))
  print(table(rows$ownership, rows$helper))
  nonliteral <- !grepl('^(NULL|TRUE|FALSE|[0-9.]+|".*"|[a-zA-Z][a-zA-Z0-9_.]*)$', rows$expression)
  print(unique(rows[nonliteral & rows$ownership == 'selected', c('helper', 'argument', 'expression')]), row.names = FALSE)
  invisible(rows)
}
if (sys.nframe() == 0L) request_shapes('evidence/baseline', 'evidence')
