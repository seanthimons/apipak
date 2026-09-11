configuration_scaffold_acceptance <- function() {
  workspace <- tempfile('configuration-scaffold-')
  dir.create(workspace)
  on.exit(unlink(workspace, recursive = TRUE), add = TRUE)
  schema <- system.file(
    'configuration/petstore.json',
    package = 'specmill',
    mustWork = TRUE
  )
  root <- file.path(workspace, 'client')
  plan <- specmill::configure_client(
    root,
    schema,
    package = 'petclient',
    naming = 'tag_prefix'
  )
  stopifnot(
    !dir.exists(root),
    length(plan$operations) == 19L,
    identical(
      plan,
      specmill::configure_client(
        root,
        schema,
        package = 'petclient',
        naming = 'tag_prefix'
      )
    ),
    all(vapply(
      plan$diagnostics,
      function(x) x$code == 'unsupported',
      logical(1)
    )),
    length(plan$diagnostics) == 0L,
    identical(
      names(plan$files),
      c(
        'schema/openapi.json',
        'specmill.yml',
        'apis/pet.yml',
        'apis/store.yml',
        'apis/user.yml'
      )
    )
  )
  ungrouped <- specmill::configure_client(
    root,
    schema,
    package = 'petclient',
    naming = 'tag_prefix',
    group_by = 'none'
  )
  stopifnot(
    identical(
      vapply(ungrouped$operations, `[[`, character(1), 'name'),
      vapply(plan$operations, `[[`, character(1), 'name')
    ),
    'apis/default.yml' %in% names(ungrouped$files)
  )
  created <- specmill::initialize_client(
    root,
    schema,
    package = 'petclient',
    title = 'Petstore Configuration Test',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'test@example.org'
    ),
    license = 'MIT + file LICENSE',
    base_url = 'https://example.invalid',
    naming = 'tag_prefix'
  )
  stopifnot(identical(attr(created, 'configuration')$files, plan$files))
  project <- specmill::load_project(root)
  for (path in grep('^apis/', names(plan$files), value = TRUE)) {
    policy <- yaml::yaml.load(plan$files[[path]])
    stopifnot(
      setequal(
        policy$selection$methods,
        c('GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'HEAD', 'OPTIONS', 'TRACE')
      ),
      !length(policy$selection$exclude),
      all(c('files', 'patterns', 'exclude') %in% names(policy$schemas)),
      all(
        c('defaults', 'operations', 'documentation', 'names') %in% names(policy)
      ),
      policy$defaults$implementation == 'generated',
      grepl(
        '# An operation must pass methods AND include',
        plan$files[[path]],
        fixed = TRUE
      )
    )
  }
  allowlists <- unlist(
    lapply(project$services, function(x) x$policy$include),
    use.names = FALSE
  )
  stopifnot(
    length(allowlists) == 19L,
    !anyDuplicated(allowlists),
    'pet_get_by_id' %in% project$services[[1L]]$policy$names
  )
  generation <- specmill::generate_client(
    root,
    config = 'specmill.yml',
    mode = 'plan'
  )
  stopifnot(
    length(generation$operations) == 19L,
    length(generation$diagnostics) == 0L
  )
  hashes <- function() {
    tools::md5sum(list.files(
      root,
      all.files = TRUE,
      recursive = TRUE,
      full.names = TRUE
    ))
  }
  before <- hashes()
  specmill::configure_client(
    root,
    schema,
    naming = 'tag_prefix',
    mode = 'apply'
  )
  stopifnot(identical(before, hashes()))
  service_file <- file.path(root, 'apis/pet.yml')
  cat('\n# User customization\n', file = service_file, append = TRUE)
  before <- hashes()
  review <- specmill::configure_client(root, schema, naming = 'tag_prefix')
  stopifnot(any(vapply(
    review$changes,
    function(x) x$action == 'conflict',
    logical(1)
  )))
  error <- tryCatch(
    specmill::configure_client(
      root,
      schema,
      naming = 'tag_prefix',
      mode = 'apply'
    ),
    error = identity
  )
  stopifnot(inherits(error, 'error'), identical(before, hashes()))
  # Different verbs on one path belong to different tags, not path-based groups.
  document <- list(
    openapi = '3.0.3',
    info = list(title = 'Tags', version = '1'),
    paths = list(
      '/shared' = list(
        get = list(
          tags = list('Pet', 'Store'),
          operationId = 'getPetById',
          responses = list('200' = list(description = 'OK'))
        ),
        post = list(
          tags = list('Store'),
          operationId = 'createOrder',
          responses = list('200' = list(description = 'OK'))
        )
      ),
      '/untagged' = list(
        get = list(responses = list('200' = list(description = 'OK')))
      )
    )
  )
  small <- file.path(workspace, 'small.json')
  write_schema <- function(x) jsonlite::write_json(x, small, auto_unbox = TRUE)
  write_schema(document)
  tagged_root <- file.path(workspace, 'tagged-package')
  specmill::initialize_client(
    tagged_root,
    small,
    package = 'taggedclient',
    title = 'Tagged Client',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'test@example.org'
    ),
    license = 'MIT + file LICENSE',
    base_url = 'https://example.invalid'
  )
  generated <- specmill::generate_client(
    tagged_root,
    config = 'specmill.yml',
    mode = 'apply'
  )
  stopifnot(
    length(generated$operations) == 3L,
    all(file.exists(file.path(
      tagged_root,
      c('R/pet.R', 'R/store.R', 'R/get_untagged.R')
    )))
  )
  specmill::generate_client(
    tagged_root,
    config = 'specmill.yml',
    mode = 'check'
  )
  small_root <- file.path(workspace, 'small-client')
  small_plan <- specmill::configure_client(
    small_root,
    small,
    package = 'pet',
    naming = 'tag_prefix',
    mode = 'apply'
  )
  small_project <- specmill::load_project(small_root)
  stopifnot(
    setequal(
      vapply(small_project$services, `[[`, character(1), 'id'),
      c('default', 'pet', 'store')
    ),
    all(
      c('missing_tag', 'multiple_tags', 'derived_name') %in%
        vapply(small_plan$diagnostics, `[[`, character(1), 'code')
    )
  )
  pet_service <- Filter(function(x) x$id == 'pet', small_project$services)[[1L]]
  pet_ops <- specmill::read_operations(small, pet_service$policy)
  stopifnot(
    length(pet_ops$operations) == 1L,
    names(pet_ops$operations) == 'pet_get_by_id',
    pet_ops$operations[[1L]]$method == 'GET'
  )
  error <- tryCatch(
    specmill::read_operations(small, list(include = 'GET /missing')),
    error = identity
  )
  stopifnot(inherits(error, 'error'))
  stopifnot(
    !length(
      specmill::read_operations(small, list(include = character()))$operations
    )
  )
  # Neither file/name collisions nor unsafe tag spelling silently lose operations.
  document$paths[['/shared']]$post$tags <- list('pet!')
  document$paths[['/shared']]$post$operationId <- 'getPetById'
  write_schema(document)
  collision_root <- file.path(workspace, 'collision')
  collision <- specmill::configure_client(
    collision_root,
    small,
    package = 'client'
  )
  stopifnot(all(
    c('group_collision', 'name_collision') %in%
      vapply(collision$diagnostics, `[[`, character(1), 'code')
  ))
  error <- tryCatch(
    specmill::configure_client(
      collision_root,
      small,
      package = 'client',
      mode = 'apply'
    ),
    error = identity
  )
  stopifnot(inherits(error, 'error'), !dir.exists(collision_root))
  document$paths[['/shared']]$post$tags <- list('Store')
  write_schema(document)
  named_collision <- specmill::configure_client(
    collision_root,
    small,
    package = 'client',
    mode = 'apply'
  )
  stopifnot(
    any(vapply(
      named_collision$diagnostics,
      function(x) x$code == 'name_collision',
      logical(1)
    )),
    file.exists(file.path(collision_root, 'apis/store.yml'))
  )
  # Generation still rejects duplicate public names across the proposed services.
  writeLines(
    'api_request <- function(method, path, path_params, query, body) NULL',
    file.path(tagged_root, 'R/api_request.R')
  )
  file.copy(
    file.path(collision_root, 'apis/store.yml'),
    file.path(tagged_root, 'apis/store.yml'),
    overwrite = TRUE
  )
  error <- tryCatch(
    specmill::generate_client(
      tagged_root,
      config = 'specmill.yml',
      mode = 'plan'
    ),
    error = identity
  )
  stopifnot(inherits(error, 'error'), grepl('collide', conditionMessage(error)))
  document$paths[['/shared']]$get$tags <- list('../../CON')
  document$paths[['/shared']]$post$tags <- list('api_request')
  write_schema(document)
  safe <- specmill::configure_client(
    collision_root,
    small,
    package = 'client',
    naming = 'tag_prefix'
  )
  stopifnot(
    all(
      c('apis/group_con.yml', 'apis/group_api_request.yml') %in%
        names(safe$files)
    ),
    !any(grepl('..', names(safe$files), fixed = TRUE))
  )
  # Schema ordering does not change the proposed configuration.
  document$paths <- rev(document$paths)
  write_schema(document)
  reordered <- specmill::configure_client(
    collision_root,
    small,
    package = 'client',
    naming = 'tag_prefix'
  )
  reordered$files[['schema/openapi.json']] <- safe$files[[
    'schema/openapi.json'
  ]]
  stopifnot(identical(safe$files, reordered$files))
  document$paths[['/shared']]$get$tags <- 'not-an-array'
  write_schema(document)
  stopifnot(inherits(
    tryCatch(
      specmill::configure_client(collision_root, small, package = 'client'),
      error = identity
    ),
    'error'
  ))
  cat(
    'Configuration scaffold: 19 Petstore operations, precise tag groups, naming, diagnostics, deterministic proposals, absent-only writes and edited-file protection passed.\n'
  )
}
if (sys.nframe() == 0L) {
  configuration_scaffold_acceptance()
}
