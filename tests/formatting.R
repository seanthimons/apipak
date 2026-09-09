formatting_acceptance <- function() {
  if (!nzchar(Sys.which('air'))) {
    cat('Formatting: Air unavailable; formatter acceptance skipped.\n')
    return(invisible(NULL))
  }
  root <- tempfile('formatted-client-')
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  fixture <- system.file('catalogue', package = 'apipak', mustWork = TRUE)
  stopifnot(all(file.copy(
    list.files(fixture, full.names = TRUE),
    root,
    recursive = TRUE
  )))
  version <- sub(
    '^air ',
    '',
    system2(Sys.which('air'), '--version', stdout = TRUE)
  )
  project <- list(
    config_version = 1L,
    services = list('service.yml'),
    formatter = list(name = 'air', version = version)
  )
  yaml::write_yaml(project, file.path(root, 'apipak.yml'))
  writeLines(
    c(
      'id: catalogue',
      'schemas: {files: [schema.json]}',
      'helper: catalogue_request'
    ),
    file.path(root, 'service.yml')
  )
  hashes <- function() {
    tools::md5sum(list.files(
      root,
      recursive = TRUE,
      full.names = TRUE,
      all.files = TRUE
    ))
  }
  before <- hashes()
  apipak::generate_client(root, config = 'apipak.yml', mode = 'plan')
  stopifnot(identical(before, hashes()))
  apipak::generate_client(root, config = 'apipak.yml', mode = 'apply')
  before <- hashes()
  apipak::generate_client(root, config = 'apipak.yml', mode = 'check')
  apipak::generate_client(root, config = 'apipak.yml', mode = 'apply')
  stopifnot(
    identical(before, hashes()),
    identical(
      jsonlite::read_json(file.path(root, '.apipak/manifest.json'))$formatter,
      project$formatter
    )
  )
  project$formatter$version <- '0.0.0'
  yaml::write_yaml(project, file.path(root, 'apipak.yml'))
  before <- hashes()
  error <- tryCatch(
    apipak::generate_client(root, config = 'apipak.yml', mode = 'apply'),
    error = identity
  )
  stopifnot(
    inherits(error, 'error'),
    grepl('version differs', conditionMessage(error)),
    identical(before, hashes())
  )
  cat(
    'Formatting: pinned Air, isolated formatting, read-only planning and unchanged second apply passed.\n'
  )
}
if (sys.nframe() == 0L) {
  formatting_acceptance()
}
