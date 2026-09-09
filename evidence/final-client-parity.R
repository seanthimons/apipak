final_client_parity <- function(root) {
  root <- normalizePath(root, winslash = '/', mustWork = TRUE)
  baseline <- normalizePath('evidence/baseline-maintenance', winslash = '/', mustWork = TRUE)
  defs <- getFromNamespace('tg_find_function_defs_in_file', 'apipak')
  current <- unlist(lapply(list.files(file.path(root, 'R'), '\\.R$', full.names = TRUE), defs), recursive = FALSE)
  frozen <- readRDS('evidence/baseline/public-contracts.rds')
  count <- 0L
  for (file in frozen) for (definition in file$definitions) {
    name <- definition$name
    original <- eval(parse(text = definition$code)[[1L]], baseenv())
    stopifnot(name %in% names(current), identical(formals(original), formals(eval(current[[name]]$expr, baseenv()))))
    count <- count + 1L
  }
  exports <- function(path) grep('^export\\(', readLines(path), value = TRUE)
  old <- exports(file.path(baseline, 'NAMESPACE'))
  new <- exports(file.path(root, 'NAMESPACE'))
  stopifnot(identical(setdiff(new, old), 'export(chemi_resolver_ghs_list_count_bulk)'), !length(setdiff(old, new)))
  render <- function(path) {
    destination <- tempfile(fileext = '.html')
    tools::Rd2HTML(tools::parse_Rd(path, encoding = 'UTF-8'), out = destination, package = 'ComptoxR')
    readLines(destination, encoding = 'UTF-8')
  }
  corrected <- character()
  documents <- list.files(file.path(baseline, 'man'), '\\.Rd$')
  for (name in documents) {
    old_path <- file.path(baseline, 'man', name)
    new_path <- file.path(root, 'man', name)
    stopifnot(file.exists(new_path))
    if (identical(readLines(old_path), readLines(new_path))) next
    before <- render(old_path)
    after <- render(new_path)
    if (identical(before, after)) next
    stopifnot(grepl('^chemi_amos_.*_keyset_pagination_bulk\\.Rd$', name),
      identical(before, gsub('(default: {})', '(default: )', after, fixed = TRUE)))
    corrected <- c(corrected, name)
  }
  stopifnot(length(corrected) == 5L)
  hashes <- jsonlite::read_json('evidence/baseline/tracked-sha256.json')
  cassettes <- grep('^tests/testthat/fixtures/.*\\.ya?ml$', names(hashes), value = TRUE)
  for (file in cassettes) stopifnot(identical(digest::digest(file = file.path(root, file), algo = 'sha256'), hashes[[file]]))
  fixtures <- list.files(file.path(root, 'tests/testthat/fixtures/apipak'), '\\.rds$', full.names = TRUE)
  for (file in fixtures) {
    values <- unlist(readRDS(file), recursive = TRUE, use.names = FALSE)
    text <- values[is.character(values)]
    stopifnot(!any(grepl('Bearer [A-Za-z0-9._-]{20}|gh[pousr]_[A-Za-z0-9]{20}|AKIA[A-Z0-9]{16}|https?://[^/ ]+:[^/@ ]+@', text)))
    secret <- Sys.getenv('ctx_api_key')
    if (nchar(secret) > 8L) stopifnot(!any(grepl(secret, text, fixed = TRUE)))
  }
  result <- list(public_formals = count, baseline_docs = length(documents), rendered_corrections = corrected,
    added_export = setdiff(new, old), unchanged_cassettes = length(cassettes), fixed_fixture_files_scanned = length(fixtures))
  jsonlite::write_json(result, 'evidence/final-client-parity.json', pretty = TRUE, auto_unbox = TRUE)
  print(result)
  invisible(result)
}
if (sys.nframe() == 0L) final_client_parity(commandArgs(trailingOnly = TRUE)[[1L]])
