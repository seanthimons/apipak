natural_products_inventory <- function() {
  file <- 'inst/schema-stress/natural-products.json'
  document <- jsonlite::read_json(file)
  parsed <- apipak::read_operations(file)
  records <- lapply(parsed$inventory, function(record) {
    operation <- document$paths[[record$path]][[tolower(record$method)]]
    list(key = record$key, status = record$status,
      request_media = names(operation$requestBody$content),
      response_media = unique(unlist(lapply(operation$responses, function(x) names(x$content)))),
      reason = record$reason)
  })
  jsonlite::write_json(list(inventory = records, diagnostics = parsed$diagnostics),
    'evidence/natural-products-inventory.json', auto_unbox = TRUE, pretty = TRUE, null = 'null')
  print(table(vapply(records, `[[`, character(1), 'status')))
  for (record in records) cat(record$key, record$status, paste(record$request_media, collapse = ','), paste(record$response_media, collapse = ','), record$reason, '\n')
  invisible(parsed)
}
if (sys.nframe() == 0L) natural_products_inventory()
