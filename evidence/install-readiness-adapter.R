install_readiness_adapter <- function(root) {
  path <- file.path(root, 'dev/unit_test_readiness_audit.R')
  baseline <- jsonlite::read_json('evidence/baseline/tracked-sha256.json')
  stopifnot(identical(digest::digest(file = path, algo = 'sha256'), baseline[['dev/unit_test_readiness_audit.R']]))
  writeLines(c(
    "# Development-only readiness adapter; policy remains client-owned YAML.",
    ".readiness_root <- apipak::script_root('unit_test_readiness_audit.R')",
    ".readiness <- new.env(parent = asNamespace('apipak'))",
    "apipak::bind_tools('readiness', .readiness)",
    ".readiness$audit_policy <- .readiness$read_audit_policy(file.path(.readiness_root, 'dev/apipak-readiness.yml'))",
    "list2env(as.list(.readiness, all.names = TRUE), envir = environment())",
    "if (sys.nframe() == 0L) unit_test_readiness_audit_main(root = .readiness_root)"
  ), path, useBytes = TRUE)
  invisible(path)
}
if (sys.nframe() == 0L) install_readiness_adapter(commandArgs(trailingOnly = TRUE)[[1L]])
