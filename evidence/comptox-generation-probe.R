comptox_generation_probe <- function(root) {
  root <- normalizePath(root, winslash = '/', mustWork = TRUE)
  callbacks <- new.env(parent = baseenv())
  sys.source(file.path(root, 'dev/apipak_callbacks.R'), callbacks)
  captured <- NULL
  context <- new.env(parent = asNamespace('apipak'))
  context$apply_files <- function(root, desired, ...) {
    captured <<- desired
    apipak::apply_files(root, desired, ...)
  }
  generate <- apipak::generate_client
  environment(generate) <- context
  files <- list.files(
    root,
    recursive = TRUE,
    full.names = TRUE,
    all.files = TRUE
  )
  before <- tools::md5sum(files)
  plan <- generate(
    root,
    config = 'apipak.yml',
    callbacks = callbacks,
    mode = 'plan'
  )
  stopifnot(identical(before, tools::md5sum(files)))
  saveRDS(
    list(desired = captured, plan = plan),
    'evidence/generation-probe.rds'
  )
  output <- tempfile('comptox-output-')
  dir.create(output)
  for (name in names(captured)) {
    path <- file.path(output, name)
    dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
    writeLines(enc2utf8(captured[[name]]), path, useBytes = TRUE)
  }
  normalize_rd <- function(x) {
    attrs <- attributes(x)[intersect(
      names(attributes(x)),
      c('Rd_tag', 'Rd_option')
    )]
    if (is.list(x)) {
      x <- Filter(
        function(value) !identical(attr(value, 'Rd_tag'), 'COMMENT'),
        x
      )
      x <- lapply(x, normalize_rd)
    } else if (is.character(x)) {
      x <- gsub('[[:space:]]+', ' ', x)
    }
    attributes(x) <- attrs
    x
  }
  parse_rd <- function(path) {
    normalize_rd(tools::parse_Rd(path, encoding = 'UTF-8'))
  }
  changed <- character()
  for (name in names(captured)[endsWith(names(captured), '.Rd')]) {
    if (
      file.exists(file.path(root, name)) &&
        !identical(
          getFromNamespace('file_text', 'apipak')(file.path(root, name)),
          captured[[name]]
        ) &&
        !identical(
          parse_rd(file.path(root, name)),
          parse_rd(file.path(output, name))
        )
    ) {
      changed <- c(changed, name)
    }
  }
  saveRDS(
    list(output = output, changed_docs = changed),
    'evidence/documentation-diff.rds'
  )
  frozen <- readRDS('evidence/baseline/public-contracts.rds')
  original_definitions <- unlist(
    lapply(frozen, function(x) x$definitions),
    recursive = FALSE
  )
  original_definitions <- stats::setNames(
    original_definitions,
    vapply(original_definitions, `[[`, character(1), 'name')
  )
  added <- character()
  for (file in names(captured)[startsWith(names(captured), 'R/')]) {
    definitions <- getFromNamespace(
      'tg_find_function_defs_in_file',
      'apipak'
    )(file.path(output, file))
    for (name in names(definitions)) {
      if (is.null(original_definitions[[name]])) {
        added <- c(added, name)
        next
      }
      original <- eval(
        parse(text = original_definitions[[name]]$code)[[1L]],
        baseenv()
      )
      candidate <- eval(definitions[[name]]$expr, baseenv())
      stopifnot(identical(formals(original), formals(candidate)))
    }
  }
  stopifnot(identical(added, 'chemi_resolver_ghs_list_count_bulk'))
  namespace_before <- readLines(
    file.path(root, 'NAMESPACE'),
    encoding = 'UTF-8'
  )
  namespace_after <- strsplit(captured$NAMESPACE, '\n', fixed = TRUE)[[1L]]
  stopifnot(
    identical(
      setdiff(namespace_after, namespace_before),
      paste0('export(', added, ')')
    ),
    !length(setdiff(namespace_before, namespace_after))
  )
  render <- function(path) {
    destination <- tempfile(fileext = '.html')
    tools::Rd2HTML(
      tools::parse_Rd(path, encoding = 'UTF-8'),
      out = destination,
      package = 'ComptoxR'
    )
    readLines(destination, encoding = 'UTF-8')
  }
  corrections <- character()
  for (name in changed) {
    before <- render(file.path(root, name))
    after <- render(file.path(output, name))
    if (identical(before, after)) {
      next
    }
    # Literal empty-map defaults were present in source docs but swallowed as Rd groups.
    stopifnot(
      grepl('^man/chemi_amos_.*_keyset_pagination_bulk\\.Rd$', name),
      identical(
        before,
        gsub('(default: {})', '(default: )', after, fixed = TRUE)
      )
    )
    corrections <- c(corrections, name)
  }
  saveRDS(
    list(
      public_formals = 'unchanged',
      added_export = added,
      documentation_corrections = corrections
    ),
    'evidence/generation-parity.rds'
  )
  print(table(vapply(plan$files, `[[`, character(1), 'action')))
  cat(
    'Rendered files:',
    length(captured),
    '; retained sources:',
    length(plan$retained_sources),
    '; changed existing Rd:',
    length(changed),
    '\nOutput:',
    output,
    '\n'
  )
  print(changed)
  invisible(list(plan = plan, changed_docs = changed, output = output))
}
if (sys.nframe() == 0L) {
  comptox_generation_probe(commandArgs(trailingOnly = TRUE)[[1L]])
}
