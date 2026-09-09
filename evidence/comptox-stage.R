comptox_stage <- function(root) {
  root <- normalizePath(root, winslash = '/', mustWork = TRUE)
  parity <- readRDS('evidence/generation-parity.rds')
  stopifnot(parity$public_formals == 'unchanged')
  generated <- readRDS('evidence/generation-probe.rds')
  baseline <- jsonlite::read_json('evidence/baseline/tracked-sha256.json')
  frozen <- readRDS('evidence/baseline/public-contracts.rds')
  adopt <- list()
  for (name in names(generated$desired)) {
    path <- file.path(root, name)
    if (!file.exists(path)) {
      next
    }
    stopifnot(
      !is.null(baseline[[name]]),
      identical(digest::digest(file = path, algo = 'sha256'), baseline[[name]])
    )
    if (startsWith(name, 'R/')) {
      stopifnot(frozen[[substring(name, 3L)]]$ownership$status == 'selected')
    } else {
      stopifnot(startsWith(name, 'man/') || name == 'NAMESPACE')
    }
    adopt[[name]] <- getFromNamespace('output_hash', 'apipak')(path)
  }
  stage <- tempfile(
    'comptox-stage-',
    tmpdir = normalizePath('evidence', winslash = '/')
  )
  dir.create(stage)
  inputs <- intersect(
    c(
      'R',
      'man',
      'inst',
      'data',
      'DESCRIPTION',
      'NAMESPACE',
      'LICENSE',
      'apis',
      'schema',
      'apipak.yml',
      'tests',
      '.Rbuildignore',
      'air.toml',
      '.air.toml'
    ),
    list.files(root, all.files = TRUE)
  )
  stopifnot(all(file.copy(file.path(root, inputs), stage, recursive = TRUE)))
  dir.create(file.path(stage, 'dev'))
  stopifnot(file.copy(
    file.path(root, 'dev/apipak_callbacks.R'),
    file.path(stage, 'dev/apipak_callbacks.R')
  ))
  saveRDS(list(root = stage, adopt = adopt), 'evidence/staged-client.rds')
  callbacks <- new.env(parent = baseenv())
  sys.source(file.path(stage, 'dev/apipak_callbacks.R'), callbacks)
  apipak::generate_client(
    stage,
    config = 'apipak.yml',
    callbacks = callbacks,
    mode = 'apply',
    adopt = adopt
  )
  hashes <- function() {
    tools::md5sum(list.files(
      stage,
      recursive = TRUE,
      full.names = TRUE,
      all.files = TRUE
    ))
  }
  before <- hashes()
  apipak::generate_client(
    stage,
    config = 'apipak.yml',
    callbacks = callbacks,
    mode = 'check'
  )
  apipak::generate_client(
    stage,
    config = 'apipak.yml',
    callbacks = callbacks,
    mode = 'apply'
  )
  stopifnot(identical(before, hashes()))
  Sys.setenv(COMPTOXR_CRAN_SAFE_TESTS = 'true', NOT_CRAN = 'false')
  Sys.unsetenv(c('ctx_api_key', 'GITHUB_OUTPUT'))
  devtools::test(
    stage,
    filter = '^contract-|^chemi_resolver_ghs_list_count_bulk$',
    stop_on_failure = TRUE
  )
  cat(
    'Isolated client:',
    stage,
    '\nReviewed adoption, check, unchanged second apply and fixed contracts passed.\n'
  )
  invisible(stage)
}
if (sys.nframe() == 0L) {
  comptox_stage(commandArgs(trailingOnly = TRUE)[[1L]])
}
