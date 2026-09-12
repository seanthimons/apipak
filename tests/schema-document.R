schema_document_acceptance <- function() {
  read_document <- getFromNamespace('read_schema_document', 'specmill')
  root <- tempfile('schema-document-')
  dir.create(root)
  on.exit(unlink(root, recursive = TRUE))
  yaml_path <- file.path(root, 'schema.YAML')
  json_path <- file.path(root, 'schema.json')
  text <- c(
    'object: {}',
    'array: []',
    'nothing: null',
    'items: [1, true, null, "x"]',
    'words: [yes, no, on, off, "true"]',
    'booleans: [true, false]',
    'numbers: [2147483648, -2147483648, 9007199254740993, 1e3, 1.25]',
    'unicode: "caf\u00e9 \u96ea"',
    'responses: {200: {description: ok}}',
    'alias: &shape {type: string}',
    'copy: *shape'
  )
  writeLines(enc2utf8(text), yaml_path, useBytes = TRUE)
  writeLines(
    paste0(
      '{"object":{},"array":[],"nothing":null,"items":[1,true,null,"x"],',
      '"words":["yes","no","on","off","true"],"booleans":[true,false],',
      '"numbers":[2147483648,-2147483648,9007199254740993,1e3,1.25],',
      '"unicode":"caf\\u00e9 \\u96ea","responses":{"200":{"description":"ok"}},',
      '"alias":{"type":"string"},"copy":{"type":"string"}}'
    ),
    json_path
  )
  stopifnot(identical(read_document(yaml_path), read_document(json_path)))
  for (bad in c(
    'a: 1\na: 2',
    'a: 1\n"a": 2',
    '200: x\n"200": y',
    'a: .inf',
    'a: .nan',
    'a: !expr stop("executed")',
    'a: !custom value',
    '? [a, b]\n: c',
    'true: value',
    'null: value',
    'a: &x {b: 1}\nc: {<<: *x}',
    '---\na: 1\n---\nb: 2',
    'a: *missing',
    'a: &cycle [*cycle]',
    'a: &cycle {self: *cycle}',
    '1.25: value',
    '9007199254740993: value',
    '!custom 200: value',
    'a: !!str [1, 2]',
    'a: !!seq {}',
    'a: !!map []',
    'a: !!null {}',
    'a: !!int []',
    'a: !!bool {}',
    'a: !!seq scalar',
    'a: !!map scalar'
  )) {
    writeLines(bad, yaml_path)
    stopifnot(inherits(
      try(read_document(yaml_path), silent = TRUE),
      'try-error'
    ))
  }
  writeLines('value: "!expr harmless string"', yaml_path)
  stopifnot(identical(read_document(yaml_path)$value, '!expr harmless string'))
  writeLines(
    c(
      'base: &base {type: string}',
      paste0('copies: [', paste(rep('*base', 1000L), collapse = ', '), ']')
    ),
    yaml_path
  )
  aliases <- read_document(yaml_path)
  stopifnot(
    length(aliases$copies) == 1000L,
    identical(aliases$copies[[1000L]], aliases$base)
  )
  cat(
    'Native schema document parity, scalar boundaries, aliases and invalid YAML passed.\n'
  )
  invisible(TRUE)
}

if (sys.nframe() == 0L) {
  schema_document_acceptance()
}
