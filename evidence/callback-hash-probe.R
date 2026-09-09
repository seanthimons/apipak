callback_hash_probe <- function(root) {
  callbacks <- new.env(parent = baseenv())
  sys.source(file.path(root, 'dev/apipak_callbacks.R'), callbacks)
  hash <- function() digest::digest(lapply(as.list(callbacks), function(x) list(deparse(formals(x)), deparse(body(x)))), algo = 'sha256')
  original <- hash()
  definitions <- unserialize(serialize(lapply(as.list(callbacks), function(x) list(formals(x), body(x))), NULL))
  project <- apipak::load_project(root, callbacks = callbacks)
  for (service in project$services) {
    parsed <- getFromNamespace('read_service_operations', 'apipak')(service)
    for (op in parsed$operations) {
      configured <- getFromNamespace('configure_operation', 'apipak')(op, service)
      apipak::render_operation(configured$operation, configured$spec)
      if (!identical(original, hash())) {
        print(waldo::compare(definitions, lapply(as.list(callbacks), function(x) list(formals(x), body(x)))))
        stop('Callback hash changed at ', op$name)
      }
    }
  }
  cat('Callback definition hash remains stable.\n')
}
if (sys.nframe() == 0L) callback_hash_probe(commandArgs(trailingOnly = TRUE)[[1L]])
