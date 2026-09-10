# Sourceable locally and in CI. Publish the returned archive without rebuilding it.
build_release <- function(
  root = '.',
  output = file.path(root, 'artifacts/release')
) {
  root <- normalizePath(root, winslash = '/', mustWork = TRUE)
  git <- function(args) {
    result <- system2(
      'git',
      c('-C', shQuote(root), args),
      stdout = TRUE,
      stderr = TRUE
    )
    if (!is.null(attr(result, 'status'))) {
      stop(paste(result, collapse = '\n'))
    }
    result
  }
  if (length(git(c('status', '--porcelain', '--untracked-files=normal')))) {
    stop('Commit source changes before building a release archive')
  }
  if (
    dir.exists(output) &&
      length(list.files(output, all.files = TRUE, no.. = TRUE))
  ) {
    stop('Use an empty output directory to avoid mixing build artifacts')
  }
  dir.create(output, recursive = TRUE, showWarnings = FALSE)
  output <- normalizePath(output, winslash = '/', mustWork = TRUE)
  revision <- git(c('rev-parse', 'HEAD'))
  stage <- tempfile('release-source-')
  dir.create(stage)
  on.exit(unlink(stage, recursive = TRUE), add = TRUE)
  snapshot <- file.path(stage, 'source.tar')
  git(c(
    'archive',
    '--format=tar',
    shQuote(paste0('--output=', snapshot)),
    revision
  ))
  source <- file.path(stage, 'source')
  dir.create(source)
  utils::untar(snapshot, exdir = source)
  metadata <- read.dcf(file.path(source, 'DESCRIPTION'))[1L, ]
  archive <- pkgbuild::build(source, dest_path = output, manual = FALSE)
  checksum <- digest::digest(file = archive, algo = 'sha256')
  rcmdcheck::rcmdcheck(
    archive,
    args = '--no-manual',
    error_on = 'warning',
    check_dir = file.path(output, 'check')
  )
  stopifnot(identical(
    checksum,
    digest::digest(file = archive, algo = 'sha256')
  ))
  release <- list(
    package = unname(metadata[['Package']]),
    version = unname(metadata[['Version']]),
    source_commit = revision,
    asset = basename(archive),
    sha256 = checksum
  )
  jsonlite::write_json(
    release,
    file.path(output, 'release.json'),
    auto_unbox = TRUE,
    pretty = TRUE
  )
  writeLines(
    paste(checksum, basename(archive), sep = '  '),
    file.path(output, 'SHA256SUMS')
  )
  print(release)
  invisible(release)
}
