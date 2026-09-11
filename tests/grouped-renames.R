grouped_rename_acceptance <- function() {
  root <- tempfile('grouped-rename-')
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  specmill::initialize_client(
    root,
    system.file('catalogue/schema.json', package = 'specmill'),
    package = 'grouptest',
    title = 'Grouped Rename Test',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'test@example.org'
    ),
    license = 'MIT + file LICENSE',
    base_url = 'https://example.invalid'
  )
  policy <- file.path(root, 'apis/default.yml')
  initial <- readLines(policy)
  baseline <- c(
    initial[seq_len(match('names:', initial) - 1L)],
    'defaults: {file: R/group.R}'
  )
  writeLines(baseline, policy)
  run <- function(mode) {
    specmill::generate_client(
      root,
      config = 'specmill.yml',
      mode = mode,
      artifacts = c('wrappers', 'documentation')
    )
  }
  run('apply')
  source <- file.path(root, 'R/group.R')
  original <- readLines(source)
  old_doc <- file.path(root, 'man/get_item.Rd')
  original_doc <- readLines(old_doc)
  renamed <- c(baseline, 'names:', '  GET /items/{item_id}: fetch_item')
  writeLines(renamed, policy)
  hashes <- function() {
    tools::md5sum(list.files(
      root,
      recursive = TRUE,
      all.files = TRUE,
      full.names = TRUE
    ))
  }
  fails_unchanged <- function() {
    before <- hashes()
    error <- tryCatch(run('apply'), error = identity)
    stopifnot(inherits(error, 'error'), identical(before, hashes()))
  }
  # Neither edited generated code nor mixed files gain rename permission.
  for (lines in list(
    c(original, '# edit'),
    c(original, 'extra <- function() 1'),
    c(original, 'extra <- 1'),
    c(original, '# lifecycle::badge("stable")')
  )) {
    writeLines(lines, source)
    fails_unchanged()
  }
  writeLines(original, source)
  writeLines(c(original_doc, '% edit'), old_doc)
  fails_unchanged()
  writeLines(original_doc, old_doc)
  # A schema-only name change has no explicit rename authorization.
  schema <- file.path(root, 'schema/openapi.json')
  document <- readLines(schema)
  writeLines(sub('get_item', 'fetch_item', document, fixed = TRUE), schema)
  writeLines(baseline, policy)
  fails_unchanged()
  writeLines(document, schema)
  writeLines(renamed, policy)
  run('apply')
  definitions <- getFromNamespace('tg_find_function_defs_in_file', 'specmill')(
    source
  )
  stopifnot(
    setequal(
      names(definitions),
      c('fetch_item', 'list_items', 'create_item', 'refresh')
    ),
    'export(fetch_item)' %in% readLines(file.path(root, 'NAMESPACE')),
    !'export(get_item)' %in% readLines(file.path(root, 'NAMESPACE')),
    file.exists(file.path(root, 'man/fetch_item.Rd')),
    !file.exists(old_doc)
  )
  before <- hashes()
  run('check')
  run('apply')
  stopifnot(identical(before, hashes()))
  cat(
    'Grouped rename: definition/export/help updated; siblings and repeat generation stable; modified source, mixed code, protected docs and unmapped renames blocked.\n'
  )
}
if (sys.nframe() == 0L) {
  grouped_rename_acceptance()
}
