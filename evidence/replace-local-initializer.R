# Replace the remaining client-owned generator, preserving its repository boundary policy.
replace_local_initializer <- function(root) {
  path <- file.path(root, 'dev/generate_local_client.R')
  baseline <- jsonlite::read_json('evidence/baseline/tracked-sha256.json')
  stopifnot(identical(digest::digest(file = path, algo = 'sha256'), baseline[['dev/generate_local_client.R']]))
  lines <- readLines(path)
  start <- match("  stage <- tempfile('local-client-')", lines)
  stopifnot(!is.na(start))
  lines <- lines[seq_len(start - 1L)]
  lines <- sub('base_url, package_name)', 'base_url, package_name, metadata)', lines, fixed = TRUE)
  lines <- sub("'comptoxr', 'wrapmaint', 'httr2'", "'comptoxr', 'apipak', 'wrapmaint', 'httr2'", lines, fixed = TRUE)
  lines <- c(lines,
    "  apipak::initialize_client(output_root, schema_path, package = package_name,",
    "    title = metadata$title, author = metadata$author, license = metadata$license, base_url = base_url)",
    "  apipak::generate_client(output_root, config = 'apipak.yml', mode = 'apply')",
    '}', '',
    'if (sys.nframe() == 0L) {',
    '  args <- commandArgs(trailingOnly = TRUE)',
    "  if (length(args) != 7L) stop('Usage: Rscript dev/generate_local_client.R <repository_root> <input_root> <schema_file> <output_root> <base_url> <package_name> <metadata.json>')",
    "  do.call(generate_local_client, c(as.list(args[1:6]), list(metadata = jsonlite::read_json(args[[7L]]))))",
    '}')
  parse(text = lines)
  writeLines(lines, path)
}
if (sys.nframe() == 0L) replace_local_initializer(commandArgs(trailingOnly = TRUE)[[1L]])
