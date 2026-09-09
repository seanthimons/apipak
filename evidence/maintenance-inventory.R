maintenance_inventory <- function(
  root,
  output = 'evidence/maintenance-inventory.json'
) {
  root <- normalizePath(root, winslash = '/', mustWork = TRUE)
  files <- list.files(
    file.path(root, 'dev'),
    '\\.R$',
    recursive = TRUE,
    full.names = TRUE
  )
  files <- files[grepl(
    '/(endpoint_eval|test_generation)/|/(stub_specs|toolkit_adapter|generate_stubs|generate_tests|calculate_coverage|detect_test_gaps|check_hook_config|check_public_api|diff_schemas|remove_experimental|unit_test_readiness_audit|endpoint_eval_utils|check-coverage|ct_endpoint_eval|chemi_endpoint_eval|epi_endpoint_eval|cc_endpoint_eval)\\.R$',
    files
  )]
  readers <- unlist(lapply(c('R', 'dev', 'tests', '.github'), function(path) {
    list.files(
      file.path(root, path),
      '\\.(R|ya?ml)$',
      recursive = TRUE,
      full.names = TRUE
    )
  }))
  texts <- lapply(readers, readLines, warn = FALSE, encoding = 'UTF-8')
  relative <- function(path) substring(path, nchar(root) + 2L)
  defs <- getFromNamespace('tg_find_function_defs_in_file', 'apipak')
  groups <- getFromNamespace('tool_groups', 'apipak')
  records <- list()
  for (file in files) {
    expressions <- as.list(parse(file))
    functions <- defs(file)
    for (name in names(functions)) {
      mentions <- vapply(
        texts,
        function(lines) any(grepl(name, lines, fixed = TRUE)),
        logical(1)
      )
      records[[length(records) + 1L]] <- list(
        file = relative(file),
        name = name,
        kind = 'local definition',
        disposition = 'pending source review',
        calls = functions[[name]]$call_names,
        readers = relative(readers[mentions])
      )
    }
    records[[length(records) + 1L]] <- list(file = relative(file), name = '<module>',
      kind = 'module entrypoint', disposition = 'pending module review',
      readers = relative(readers[vapply(texts, function(lines) any(grepl(basename(file), lines, fixed = TRUE)), logical(1))]))
    bindings <- apipak:::tg_find_calls(expressions, 'bind_tools')
    bound_groups <- unique(vapply(bindings, function(call) {
      if (length(call) >= 2L && is.character(call[[2L]]) && length(call[[2L]]) == 1L) call[[2L]] else ''
    }, character(1)))
    for (group in intersect(bound_groups, names(groups))) {
      for (name in groups[[group]]) {
        mentions <- vapply(
          texts,
          function(lines) any(grepl(name, lines, fixed = TRUE)),
          logical(1)
        )
        records[[length(records) + 1L]] <- list(
          file = relative(file),
          name = name,
          kind = paste('bound toolkit group', group),
          disposition = 'replace compatibility caller after YAML migration',
          readers = relative(readers[mentions])
        )
      }
    }
  }
  jsonlite::write_json(
    records,
    output,
    pretty = TRUE,
    auto_unbox = TRUE,
    null = 'null'
  )
  print(table(vapply(records, `[[`, character(1), 'kind')))
  invisible(records)
}
if (sys.nframe() == 0L) {
  maintenance_inventory(commandArgs(trailingOnly = TRUE)[[1L]])
}
