# The client pin changes only after the public artifact passes a fresh install.
adopt_release <- function(root, version, source_commit, sha256) {
  root <- normalizePath(root, winslash = '/', mustWork = TRUE)
  pin <- list(package = 'apipak', version = version,
    source_commit = source_commit,
    asset = paste0('apipak_', version, '.tar.gz'),
    url = paste0('https://github.com/seanthimons/apipak/releases/download/v', version, '/apipak_', version, '.tar.gz'),
    sha256 = sha256,
    policy_version = 'comptox-public-1')
  archive <- tempfile(fileext = '.tar.gz')
  curl::curl_download(pin$url, archive, quiet = TRUE)
  stopifnot(identical(digest::digest(file = archive, algo = 'sha256'), pin$sha256))
  library <- normalizePath('evidence', winslash = '/', mustWork = TRUE)
  library <- file.path(library, 'release-library')
  dir.create(library, showWarnings = FALSE)
  status <- system2(file.path(R.home('bin'), if (.Platform$OS.type == 'windows') 'R.exe' else 'R'),
    c('CMD', 'INSTALL', paste0('--library=', shQuote(library)), shQuote(archive)))
  stopifnot(status == 0L, as.character(packageVersion(pin$package, lib.loc = library)) == pin$version)
  jsonlite::write_json(pin, file.path(root, 'dev/toolkit-lock.json'), auto_unbox = TRUE, pretty = TRUE)
  # Source the new bootstrap outside the client and let it resolve the reviewed pin.
  commands <- new.env(parent = baseenv())
  withr::local_dir(tempdir())
  sys.source(file.path(root, 'dev/install_toolkit.R'), commands)
  commands$install_toolkit(lib = library)
  stopifnot(identical(commands$.toolkit_root, root))
  cat('Published immutable archive SHA-256 verified; isolated installation and outside-root pinned installer passed:', library, '\n')
}
if (sys.nframe() == 0L) do.call(adopt_release, as.list(commandArgs(trailingOnly = TRUE)))
