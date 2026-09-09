# Explicit one-time schema GET; never call an operation in this service.
snapshot_natural_products <- function() {
  source <- 'https://api.naturalproducts.net/latest/openapi.json'
  destination <- 'inst/schema-stress/natural-products.json'
  if (file.exists(destination)) stop('Snapshot already exists; refreshing is a separate reviewed change')
  dir.create(dirname(destination), recursive = TRUE, showWarnings = FALSE)
  curl::curl_download(source, destination, quiet = TRUE)
  document <- jsonlite::read_json(destination)
  record <- list(source = source, retrieved_utc = format(Sys.time(), tz = 'UTC', usetz = TRUE),
    sha256 = digest::digest(file = destination, algo = 'sha256'), openapi = document$openapi,
    servers = document$servers, scope = 'Schema stress testing only; no operation requests')
  jsonlite::write_json(record, 'inst/schema-stress/natural-products-origin.json', pretty = TRUE, auto_unbox = TRUE)
  print(record)
}
if (sys.nframe() == 0L) snapshot_natural_products()
