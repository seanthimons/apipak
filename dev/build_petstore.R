# Full-schema demonstration using specmill's existing configuration mechanisms.
build_petstore <- function(
  output = 'artifacts/petstore-full',
  templates = 'dev/petstore'
) {
  if (file.exists(output)) {
    stop('Choose a new output directory')
  }
  templates <- normalizePath(templates, winslash = '/', mustWork = TRUE)
  dir.create(output, recursive = TRUE)
  output <- normalizePath(output, winslash = '/', mustWork = TRUE)
  schema <- file.path(output, 'openapi.json')
  url <- 'https://petstore3.swagger.io/api/v3/openapi.json'
  utils::download.file(url, schema, mode = 'wb', quiet = TRUE)
  jsonlite::write_json(
    list(
      url = url,
      retrieved_at = format(Sys.time(), tz = 'UTC', usetz = TRUE),
      sha256 = digest::digest(file = schema, algo = 'sha256')
    ),
    file.path(output, 'schema-origin.json'),
    auto_unbox = TRUE,
    pretty = TRUE
  )
  root <- file.path(output, 'petstoretrial')
  specmill::initialize_client(
    root,
    schema,
    package = 'petstoretrial',
    title = 'Complete Petstore Configuration Example',
    license = 'MIT + file LICENSE',
    author = list(
      given = 'Example',
      family = 'Maintainer',
      email = 'you@example.org'
    ),
    base_url = 'https://petstore3.swagger.io/api/v3'
  )
  native <- specmill::generate_client(
    root,
    config = 'specmill.yml',
    mode = 'plan'
  )
  saveRDS(native, file.path(output, 'native-plan.rds'))
  # Keep the initializer's service as an explicit unconfigured baseline.
  file.copy(file.path(root, 'specmill.yml'), file.path(root, 'native.yml'))
  cat(
    '\n^native\\.yml$\n',
    file = file.path(root, '.Rbuildignore'),
    append = TRUE
  )
  yaml::write_yaml(
    list(
      config_version = 1L,
      package = 'petstoretrial',
      services = list('apis/pet.yml', 'apis/store.yml', 'apis/user.yml')
    ),
    file.path(root, 'specmill.yml')
  )
  for (group in c('pet', 'store', 'user')) {
    file.copy(
      file.path(templates, paste0(group, '.yml')),
      file.path(root, 'apis')
    )
    file.copy(
      file.path(templates, paste0(group, '_custom.R')),
      file.path(root, 'R')
    )
  }
  file.copy(
    file.path(templates, 'api_request.R'),
    file.path(root, 'R'),
    overwrite = TRUE
  )
  desc::desc_set(
    Suggests = 'testthat, callr, httpuv',
    file = file.path(root, 'DESCRIPTION')
  )
  dir.create(file.path(root, 'tests/testthat'), recursive = TRUE)
  file.copy(
    file.path(templates, 'test-http.R'),
    file.path(root, 'tests/testthat')
  )
  writeLines(
    c(
      'library(testthat)',
      'library(petstoretrial)',
      "test_check('petstoretrial')"
    ),
    file.path(root, 'tests/testthat.R')
  )
  check_petstore(root)
}

# Revalidate edited client configuration without downloading or initializing again.
check_petstore <- function(root) {
  root <- normalizePath(root, winslash = '/', mustWork = TRUE)
  output <- dirname(root)
  native <- readRDS(file.path(output, 'native-plan.rds'))
  configured <- specmill::generate_client(
    root,
    config = 'specmill.yml',
    mode = 'apply',
    artifacts = c('wrappers', 'documentation')
  )
  # Existing implementations also own their Rd files. Document in a temporary
  # copy and copy only those six topics; specmill documents the generated code.
  stage <- tempfile('petstore-docs-')
  dir.create(stage)
  on.exit(unlink(stage, recursive = TRUE), add = TRUE)
  file.copy(
    file.path(root, c('DESCRIPTION', 'LICENSE', 'R', 'NAMESPACE')),
    stage,
    recursive = TRUE
  )
  roxygen2::roxygenise(stage, roclets = 'rd')
  custom <- c(
    'pet_create',
    'pet_update',
    'pet_upload_image',
    'store_order_create',
    'user_create',
    'user_update'
  )
  dir.create(file.path(root, 'man'), showWarnings = FALSE)
  file.copy(
    file.path(stage, 'man', paste0(custom, '.Rd')),
    file.path(root, 'man'),
    overwrite = TRUE
  )
  stopifnot(
    length(configured$operations) == 19L,
    !length(configured$diagnostics),
    length(configured$mapping_diagnostics) == 2L,
    length(configured$retained_diagnostics) == 6L
  )
  saveRDS(configured, file.path(output, 'configured-plan.rds'))
  selected <- Filter(function(x) x$status != 'excluded', configured$inventory)
  stopifnot(
    length(selected) == 19L,
    !anyDuplicated(vapply(selected, `[[`, character(1), 'key'))
  )
  coverage <- do.call(
    rbind,
    lapply(selected, function(x) {
      operation <- Filter(
        function(op) identical(op$key, x$key),
        configured$operations
      )[[1L]]
      data.frame(
        group = x$service,
        endpoint = x$key,
        function_name = operation$name,
        implementation = x$status,
        reason = x$reason
      )
    })
  )
  utils::write.csv(
    coverage,
    file.path(output, 'endpoint-coverage.csv'),
    row.names = FALSE
  )
  hashes <- function() {
    tools::md5sum(list.files(
      root,
      recursive = TRUE,
      all.files = TRUE,
      full.names = TRUE
    ))
  }
  # Refresh inputs after documenting client-owned topics, then verify a no-op.
  specmill::generate_client(
    root,
    config = 'specmill.yml',
    mode = 'apply',
    artifacts = c('wrappers', 'documentation')
  )
  before <- hashes()
  specmill::generate_client(
    root,
    config = 'specmill.yml',
    mode = 'check',
    artifacts = c('wrappers', 'documentation')
  )
  specmill::generate_client(
    root,
    config = 'specmill.yml',
    mode = 'apply',
    artifacts = c('wrappers', 'documentation')
  )
  stopifnot(identical(before, hashes()))
  testthat::test_local(root, stop_on_failure = TRUE)
  archive <- pkgbuild::build(root, dest_path = output, manual = FALSE)
  checked <- rcmdcheck::rcmdcheck(
    archive,
    args = '--no-manual',
    error_on = 'warning',
    check_dir = file.path(output, 'check')
  )
  library <- file.path(output, 'library')
  dir.create(library)
  live <- callr::r(
    function(archive, library) {
      utils::install.packages(
        archive,
        repos = NULL,
        type = 'source',
        lib = library
      )
      library(petstoretrial, lib.loc = library)
      stopifnot(length(getNamespaceExports('petstoretrial')) == 19L)
      direct <- function(path) {
        req <- httr2::request(paste0(
          'https://petstore3.swagger.io/api/v3',
          path
        ))
        req <- httr2::req_headers(req, Accept = 'application/json')
        httr2::resp_body_json(
          httr2::req_perform(httr2::req_timeout(req, 30)),
          simplifyVector = FALSE
        )
      }
      pets <- petstoretrial::pet_find_by_status('available')
      stopifnot(
        length(pets) > 0L,
        identical(pets, direct('/pet/findByStatus?status=available'))
      )
      pet <- petstoretrial::pet_get(pets[[1L]]$id)
      stopifnot(identical(pet, direct(paste0('/pet/', pets[[1L]]$id))))
      inventory <- petstoretrial::store_inventory()
      stopifnot(identical(inventory, direct('/store/inventory')))
      list(
        checked_at = format(Sys.time(), tz = 'UTC', usetz = TRUE),
        pets = pets,
        pet = pet,
        inventory = inventory
      )
    },
    args = list(archive, library),
    libpath = c(library, .libPaths()),
    timeout = 180
  )
  saveRDS(live, file.path(output, 'live-responses.rds'), version = 2)
  result <- list(
    native_operations = length(native$operations),
    native_diagnostics = length(native$diagnostics),
    exported_operations = nrow(coverage),
    mapped = length(configured$mapping_diagnostics),
    client_owned = length(configured$retained_diagnostics),
    second_apply_unchanged = TRUE,
    errors = checked$errors,
    warnings = checked$warnings,
    notes = checked$notes,
    live_checked_at = live$checked_at,
    available_pets = length(live$pets),
    live_direct_responses_match = TRUE,
    archive = archive,
    sha256 = digest::digest(file = archive, algo = 'sha256')
  )
  jsonlite::write_json(
    result,
    file.path(output, 'result.json'),
    auto_unbox = TRUE,
    pretty = TRUE
  )
  print(result)
  invisible(result)
}
