verify_local_initializer <- function(root) {
  root <- normalizePath(root, winslash = '/', mustWork = TRUE)
  commands <- new.env(parent = baseenv())
  sys.source(file.path(root, 'dev/generate_local_client.R'), commands)
  input <- tempfile('initializer-input-')
  dir.create(input)
  file.copy(system.file('catalogue/schema.json', package = 'specmill'), input)
  output <- tempfile('initializer-output-')
  metadata <- list(title = 'Temporary API Client',
    author = list(given = 'Test', family = 'Maintainer', email = 'maintainer@example.org'),
    license = 'MIT + file LICENSE')
  withr::local_dir(tempdir())
  error <- tryCatch(commands$generate_local_client(root, input, 'schema.json',
    file.path(root, 'forbidden-client'), 'https://example.invalid', 'temporaryclient', metadata), error = identity)
  stopifnot(inherits(error, 'error'), !dir.exists(file.path(root, 'forbidden-client')))
  commands$generate_local_client(root, input, 'schema.json', output,
    'https://example.invalid', 'temporaryclient', metadata)
  specmill::generate_client(output, config = 'specmill.yml', mode = 'check')
  fields <- read.dcf(file.path(output, 'DESCRIPTION'))
  stopifnot(grepl('Test', fields[[1L, 'Authors@R']]),
    !grepl('specmill|ComptoxR', fields[[1L, 'Imports']]))
  installer <- new.env(parent = baseenv())
  sys.source(file.path(root, 'dev/install_toolkit.R'), installer)
  stopifnot(identical(installer$.toolkit_root, root),
    'path' %in% names(formals(covr::package_coverage)))
  cat('Local initializer: explicit metadata, existing boundary policy, outside-root sourceability and deterministic generation passed.\n')
}
if (sys.nframe() == 0L) verify_local_initializer(commandArgs(trailingOnly = TRUE)[[1L]])
