adopt_comptox <- function(root) {
  root <- normalizePath(root, winslash = '/', mustWork = TRUE)
  reviewed <- readRDS('evidence/staged-client.rds')
  desired <- readRDS('evidence/generation-probe.rds')$desired
  parity <- readRDS('evidence/generation-parity.rds')
  baseline <- jsonlite::read_json('evidence/baseline/tracked-sha256.json')
  stopifnot(parity$public_formals == 'unchanged')
  for (name in names(desired)) {
    path <- file.path(root, name)
    if (!file.exists(path)) next
    stopifnot(name %in% names(reviewed$adopt),
      identical(digest::digest(file = path, algo = 'sha256'), baseline[[name]]),
      identical(apipak:::output_hash(path), reviewed$adopt[[name]]))
  }
  callbacks <- new.env(parent = baseenv())
  sys.source(file.path(root, 'dev/apipak_callbacks.R'), callbacks)
  plan <- apipak::generate_client(root, config = 'apipak.yml', callbacks = callbacks,
    mode = 'plan', adopt = reviewed$adopt)
  stopifnot(!any(vapply(plan$files, `[[`, character(1), 'action') == 'protected'))
  jsonlite::write_json(plan$files, 'evidence/adoption-plan.json', pretty = TRUE, auto_unbox = TRUE)
  apipak::generate_client(root, config = 'apipak.yml', callbacks = callbacks,
    mode = 'apply', adopt = reviewed$adopt)
  for (name in names(desired)) {
    stopifnot(identical(apipak:::output_hash(file.path(root, name)), apipak:::text_hash(desired[[name]])))
  }
  hashes <- function() tools::md5sum(list.files(root, recursive = TRUE, all.files = TRUE, full.names = TRUE))
  before <- hashes()
  apipak::generate_client(root, config = 'apipak.yml', callbacks = callbacks, mode = 'check')
  apipak::generate_client(root, config = 'apipak.yml', callbacks = callbacks, mode = 'apply')
  stopifnot(identical(before, hashes()))
  withr::local_envvar(c(COMPTOXR_CRAN_SAFE_TESTS = 'true', NOT_CRAN = 'false', ctx_api_key = NA, GITHUB_OUTPUT = NA))
  devtools::test(root, filter = '^contract-|^chemi_resolver_ghs_list_count_bulk$|hooks|diff_schemas', stop_on_failure = TRUE)
  cat('Client adoption: reviewed baseline hashes, staged output identity, check, no-op second apply and offline contracts/hooks/diff checks passed.\n')
}
if (sys.nframe() == 0L) adopt_comptox(commandArgs(trailingOnly = TRUE)[[1L]])
