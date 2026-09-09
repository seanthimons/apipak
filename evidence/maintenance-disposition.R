# Baseline definition/caller ledger. Paths refer to the frozen 4fd720b client.
maintenance_disposition <- function(root) {
  root <- normalizePath(root, winslash = '/', mustWork = TRUE)
  records <- jsonlite::read_json('evidence/maintenance-inventory.json')
  stopifnot(length(records) == 244L)
  target <- function(file) {
    if (grepl('generate_local_client', file)) return(c('R/initialization.R: initialize_client; R/generation.R: generate_client', 'Only client repository-boundary policy remains; explicit metadata replaces hard-coded authorship and embedded transport/scaffolding.'))
    if (grepl('install_toolkit', file)) return(c('dev/install_toolkit.R', 'Necessary pre-install bootstrap: script-relative lockfile, checksum verification and isolated R CMD INSTALL; cannot depend on the package it installs.'))
    if (grepl('unit_test_readiness_audit', file)) return(c('R/readiness.R', 'Client audit policy is apipak-readiness.yml; command binds installed functions.'))
    if (grepl('07_token_preflight', file)) return(c('R/maintenance.R: credential_status, credential_preflight', 'dev/token_preflight.R retains only the client environment name and recording guidance.'))
    if (grepl('calculate_coverage', file)) return(c('R/coverage.R: coverage_report', 'Client partitions and badge paths are apipak-coverage.yml.'))
    if (grepl('detect_test_gaps', file)) return(c('R/gaps.R: test_gap_report', 'Retired manifest/protection suppression; fixed contracts and manual wrappers are separate.'))
    if (grepl('diff_schemas', file)) return(c('R/schema_reports.R: schema_diff; R/diff.R', 'Thin command retains schema family policies; parser errors block.'))
    if (grepl('check_hook_config', file)) return(c('R/maintenance.R: check_client_hooks', 'Runtime registry remains client-owned.'))
    if (grepl('check_public_api', file)) return(c('R/maintenance.R: check_public_boundary', 'Public allow/exclusion policy is client YAML.'))
    if (grepl('check-coverage', file)) return(c('covr::package_coverage', 'Thin command invokes existing dependency; obsolete pipeline lane removed.'))
    if (grepl('remove_experimental', file)) return(c('R/generation.R; R/application.R', 'Deleted broad filename/lifecycle remover; only explicit exclusions retire verified ownership.'))
    if (grepl('test_generation/|generate_tests', file)) return(c('R/test_renderer.R; R/commands.R; R/gaps.R', 'Fixed client RDS contracts replace wrapper-derived weak assertions; legacy renderer and orchestration retired.'))
    if (grepl('stub_specs', file)) return(c('R/configuration.R; R/mappings.R; R/hooks.R', 'Selection, names, request mapping and docs move to apis/*.yml; chemistry expressions remain named dev/apipak_callbacks.R callbacks.'))
    if (grepl('toolkit_adapter', file)) return(c('R/maintenance.R: inspect_client; R/generation.R: generate_client', 'comptox_inventory is a thin client callback loader; compatibility generation entrypoints retired.'))
    if (grepl('endpoint_eval_utils', file)) return(c('R/maintenance.R: script_root', 'Retired loader and globals; explicit package root and callback environments.'))
    if (grepl('endpoint_eval/|endpoint_eval\\.R$|generate_stubs', file)) return(c('R/configuration.R; R/operations.R; R/mappings.R; R/generation.R; R/documentation.R; R/commands.R', 'General parser/rendering replaces client generator; chemistry policy is YAML/callbacks, no chemistry-name inference in the shared engine.'))
    stop('Unreviewed module: ', file)
  }
  for (i in seq_along(records)) {
    record <- records[[i]]
    replacement <- target(record$file)
    record$disposition <- replacement[[2L]]
    record$replacement <- if (record$kind != 'module entrypoint' &&
      exists(record$name, asNamespace('apipak'), inherits = FALSE)) {
      paste0('installed apipak namespace: ', record$name, '; ', replacement[[1L]])
    } else replacement[[1L]]
    record$caller_disposition <- lapply(record$readers, function(reader) list(
      path = reader, disposition = if (!file.exists(file.path(root, reader))) 'retired' else
        if (startsWith(reader, 'dev/migration-evidence/')) 'historical baseline reproduction; replay at 4fd720b' else
          if (startsWith(reader, 'tests/')) 'current targeted regression or retained runtime test' else
            'current thin command, client policy/callback, or workflow'))
    records[[i]] <- record
  }
  jsonlite::write_json(list(baseline = '4fd720b97fb2f7f2abf131925e9270b0c11b057a',
    records = records), 'evidence/maintenance-disposition.json', pretty = TRUE, auto_unbox = TRUE, null = 'null')
  # Active source calls may not refer to retired implementation paths.
  readers <- unlist(lapply(c('dev', 'tests', '.github'), function(path)
    list.files(file.path(root, path), '\\.(R|ya?ml)$', recursive = TRUE, full.names = TRUE)))
  readers <- readers[!grepl('/migration-evidence/', readers)]
  stale <- Filter(function(path) any(grepl('source.*(endpoint_eval/|test_generation/|stub_specs\\.R|remove_experimental\\.R)',
    readLines(path, warn = FALSE, encoding = 'UTF-8'))), readers)
  stopifnot(!length(stale))
  cat('244 baseline definitions, compatibility bindings and modules have replacements and caller dispositions; no active retired source calls.\n')
}
if (sys.nframe() == 0L) maintenance_disposition(commandArgs(trailingOnly = TRUE)[[1L]])
