# Read-only smoke check for the installed client against the live demo.
check_live_petstore <- function() {
  direct <- function(path) {
    request <- httr2::request(paste0(
      'https://petstore3.swagger.io/api/v3',
      path
    ))
    response <- httr2::req_perform(httr2::req_timeout(request, 30))
    stopifnot(httr2::resp_status(response) == 200L)
    httr2::resp_body_json(response, simplifyVector = FALSE)
  }
  pets <- petstoretrial::findPetsByStatus('available')
  stopifnot(is.list(pets), length(pets) > 0L)
  valid_pets <- vapply(
    pets,
    function(pet) {
      is.character(pet$name) &&
        length(pet$name) == 1L &&
        is.list(pet$photoUrls) &&
        all(vapply(pet$photoUrls, is.character, logical(1))) &&
        identical(pet$status, 'available')
    },
    logical(1)
  )
  stopifnot(identical(pets, direct('/pet/findByStatus?status=available')))
  id <- pets[[1L]]$id
  stopifnot(is.numeric(id), length(id) == 1L, is.finite(id))
  pet <- petstoretrial::getPetById(id)
  stopifnot(identical(pet$id, id))
  stopifnot(identical(
    pet,
    direct(paste0('/pet/', format(id, scientific = FALSE)))
  ))
  inventory <- petstoretrial::getInventory()
  stopifnot(is.list(inventory), length(inventory) > 0L)
  stopifnot(all(vapply(
    inventory,
    function(n) {
      is.numeric(n) && length(n) == 1L && is.finite(n) && n == floor(n)
    },
    logical(1)
  )))
  stopifnot(identical(inventory, direct('/store/inventory')))
  list(
    checked_at = format(Sys.time(), tz = 'UTC', usetz = TRUE),
    available_pets = length(pets),
    selected_pet_id = id,
    direct_responses_match = TRUE,
    schema_fields_checked = c('name', 'photoUrls', 'status'),
    schema_invalid_pet_ids = lapply(pets[!valid_pets], function(pet) pet$id),
    responses = list(pets = pets, pet = pet, inventory = inventory)
  )
}

# Build from the live service's schema; only GET endpoints are selected/called.
try_petstore <- function(output = 'artifacts/petstore-live') {
  if (file.exists(output)) {
    stop('Choose a new trial directory')
  }
  dir.create(output, recursive = TRUE)
  output <- normalizePath(output, winslash = '/', mustWork = TRUE)
  url <- 'https://petstore3.swagger.io/api/v3/openapi.json'
  schema <- file.path(output, 'petstore.json')
  utils::download.file(url, schema, mode = 'wb', quiet = TRUE)
  document <- jsonlite::read_json(schema)
  jsonlite::write_json(
    list(
      url = url,
      retrieved_at = format(Sys.time(), tz = 'UTC', usetz = TRUE),
      api_version = document$info$version,
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
    title = 'Live Petstore Client Trial',
    author = list(
      given = 'Example',
      family = 'Maintainer',
      email = 'you@example.org'
    ),
    license = 'MIT + file LICENSE',
    base_url = 'https://petstore3.swagger.io/api/v3'
  )
  full_plan <- specmill::generate_client(
    root,
    config = 'specmill.yml',
    mode = 'plan'
  )
  saveRDS(full_plan, file.path(output, 'full-schema-plan.rds'))
  selected <- c('/pet/findByStatus', '/pet/{petId}', '/store/inventory')
  service_path <- file.path(root, 'apis/default.yml')
  service <- yaml::read_yaml(service_path)
  service$schemas$files <- as.list(service$schemas$files)
  service$selection <- list(
    methods = list('GET'),
    exclude = as.list(paste0(
      '^\\Q',
      setdiff(names(document$paths), selected),
      '\\E$'
    ))
  )
  yaml::write_yaml(service, service_path)
  pet <- list(id = 1L, name = 'Miso', photoUrls = list(), status = 'available')
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
    findPetsByStatus = contract(
      list(status = 'available'),
      'GET',
      '/pet/findByStatus',
      list(),
      list(status = 'available'),
      NULL,
      list(pet)
    ),
    getPetById = contract(
      list(petId = 1L),
      'GET',
      '/pet/{petId}',
      list(petId = 1L),
      list(),
      NULL,
      pet
    ),
    getInventory = contract(
      list(),
      'GET',
      '/store/inventory',
      list(),
      list(),
      NULL,
      list(available = 2L)
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
  live <- callr::r(
    function(archive, library, check_live) {
      utils::install.packages(
        archive,
        repos = NULL,
        type = 'source',
        lib = library
      )
      stopifnot(!'specmill' %in% names(getNamespaceImports('petstoretrial')))
      check_live()
    },
    args = list(
      archive = archive,
      library = library,
      check_live = check_live_petstore
    ),
    libpath = c(library, .libPaths()),
    timeout = 180
  )
  saveRDS(live$responses, file.path(output, 'live-responses.rds'), version = 2)
  live$responses <- NULL
  result <- list(
    package = 'petstoretrial',
    schema_source = url,
    operations = names(plan$operations),
    diagnostics = length(plan$diagnostics),
    full_schema_diagnostics = length(full_plan$diagnostics),
    live = live,
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
