# A new-schema trial with fixed expectations, no calls to the remote API.
try_petstore <- function(output = 'artifacts/petstore-trial') {
  if (file.exists(output)) {
    stop('Choose a new trial directory')
  }
  dir.create(output, recursive = TRUE)
  output <- normalizePath(output, winslash = '/', mustWork = TRUE)
  revision <- '989902919903b590e789f84501d8b937fa621fdf'
  url <- paste0(
    'https://raw.githubusercontent.com/OAI/OpenAPI-Specification/',
    revision,
    '/_archive_/schemas/v3.0/pass/petstore.yaml'
  )
  yaml_path <- file.path(output, 'petstore.yaml')
  utils::download.file(url, yaml_path, mode = 'wb', quiet = TRUE)
  document <- yaml::yaml.load_file(
    yaml_path,
    eval.expr = FALSE,
    handlers = list(seq = as.list)
  )
  schema <- file.path(output, 'petstore.json')
  jsonlite::write_json(document, schema, auto_unbox = TRUE, pretty = TRUE)
  jsonlite::write_json(
    list(
      url = url,
      source_commit = revision,
      sha256 = digest::digest(file = yaml_path, algo = 'sha256')
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
    title = 'Petstore Schema Trial',
    author = list(
      given = 'Example',
      family = 'Maintainer',
      email = 'you@example.org'
    ),
    license = 'MIT + file LICENSE',
    base_url = 'https://petstore.example.invalid/v1'
  )
  pet <- list(id = 1L, name = 'Miso')
  contract <- function(
    inputs,
    method,
    path,
    path_params,
    query,
    body,
    response
  ) {
    list(
      inputs = inputs,
      calls = list(list(
        helper = 'api_request',
        arguments = list(
          method = method,
          path = path,
          path_params = path_params,
          query = query,
          body = body
        ),
        response = response
      )),
      result = response
    )
  }
  contracts <- list(
    listPets = contract(
      list(limit = 2L),
      'GET',
      '/pets',
      list(),
      list(limit = 2L),
      NULL,
      list(pet)
    ),
    showPetById = contract(
      list(petId = '1'),
      'GET',
      '/pets/{petId}',
      list(petId = '1'),
      list(),
      NULL,
      pet
    ),
    createPets = contract(
      list(body = pet),
      'POST',
      '/pets',
      list(),
      list(),
      pet,
      NULL
    )
  )
  dir.create(file.path(root, 'tests/testthat/fixtures'), recursive = TRUE)
  saveRDS(
    contracts,
    file.path(root, 'tests/testthat/fixtures/contracts.rds'),
    version = 2
  )
  cat(
    '\ncontracts_file: tests/testthat/fixtures/contracts.rds\n',
    file = file.path(root, 'apis/default.yml'),
    append = TRUE
  )
  writeLines(
    c(
      'library(testthat)',
      'library(petstoretrial)',
      "test_check('petstoretrial')"
    ),
    file.path(root, 'tests/testthat.R')
  )
  plan <- specmill::generate_client(
    root,
    config = 'specmill.yml',
    mode = 'plan'
  )
  stopifnot(length(plan$operations) == 3L, !length(plan$diagnostics))
  saveRDS(plan, file.path(output, 'generation-plan.rds'))
  specmill::generate_client(root, config = 'specmill.yml', mode = 'apply')
  specmill::generate_client(root, config = 'specmill.yml', mode = 'check')
  hashes <- function() {
    tools::md5sum(list.files(
      root,
      recursive = TRUE,
      all.files = TRUE,
      full.names = TRUE
    ))
  }
  before <- hashes()
  specmill::generate_client(root, config = 'specmill.yml', mode = 'apply')
  stopifnot(identical(before, hashes()))
  testthat::test_local(root, filter = '^contract-', stop_on_failure = TRUE)
  archive <- pkgbuild::build(root, dest_path = output, manual = FALSE)
  checked <- rcmdcheck::rcmdcheck(
    archive,
    args = '--no-manual',
    error_on = 'warning',
    check_dir = file.path(output, 'check')
  )
  library <- file.path(output, 'library')
  dir.create(library)
  callr::r(
    function(archive, library) {
      utils::install.packages(
        archive,
        repos = NULL,
        type = 'source',
        lib = library
      )
      stopifnot(!'specmill' %in% names(getNamespaceImports('petstoretrial')))
      testthat::local_mocked_bindings(
        api_request = function(...) list(...),
        .package = 'petstoretrial'
      )
      stopifnot(identical(
        petstoretrial::showPetById('7')$path_params,
        list(petId = '7')
      ))
    },
    args = list(archive = archive, library = library),
    libpath = c(library, .libPaths())
  )
  result <- list(
    package = 'petstoretrial',
    schema_source = url,
    operations = names(plan$operations),
    diagnostics = length(plan$diagnostics),
    second_apply_unchanged = TRUE,
    errors = checked$errors,
    warnings = checked$warnings,
    notes = checked$notes,
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
