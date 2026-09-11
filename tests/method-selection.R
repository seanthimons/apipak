method_selection_acceptance <- function() {
  root <- tempfile('method-selection-')
  on.exit(unlink(root, recursive = TRUE), add = TRUE)
  specmill::initialize_client(
    root,
    system.file('configuration/petstore.json', package = 'specmill'),
    package = 'petclient',
    title = 'Method Selection Test',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'test@example.org'
    ),
    license = 'MIT + file LICENSE',
    base_url = 'https://example.invalid',
    naming = 'tag_prefix'
  )
  run <- function(mode) {
    specmill::generate_client(
      root,
      config = 'specmill.yml',
      mode = mode
    )
  }
  policies <- list.files(file.path(root, 'apis'), full.names = TRUE)
  # Older configurations may rely on schema names instead of explicit mappings.
  store <- file.path(root, 'apis/store.yml')
  policy <- yaml::read_yaml(store, handlers = list(seq = function(x) x))
  policy$names <- NULL
  yaml::write_yaml(policy, store)
  original <- run('apply')
  saved <- lapply(policies, readLines)
  for (path in policies) {
    policy <- yaml::read_yaml(path, handlers = list(seq = function(x) x))
    policy$selection$methods <- list('GET', 'POST')
    yaml::write_yaml(policy, path)
  }
  hashes <- function() {
    tools::md5sum(list.files(
      root,
      recursive = TRUE,
      all.files = TRUE,
      full.names = TRUE
    ))
  }
  source <- file.path(root, 'R/pet.R')
  original_source <- readLines(source)
  for (extra in c('# manual edit', 'unowned <- function() 1')) {
    writeLines(c(original_source, extra), source)
    before <- hashes()
    error <- tryCatch(run('apply'), error = identity)
    stopifnot(inherits(error, 'error'), identical(before, hashes()))
  }
  writeLines(original_source, source)
  help <- file.path(root, 'man/pet_delete.Rd')
  original_help <- readLines(help)
  writeLines(c(original_help, '% manual edit'), help)
  before <- hashes()
  error <- tryCatch(run('apply'), error = identity)
  stopifnot(inherits(error, 'error'), identical(before, hashes()))
  writeLines(original_help, help)
  selected <- run('apply')
  retained <- Filter(
    function(op) op$method %in% c('GET', 'POST'),
    original$operations
  )
  excluded <- Filter(
    function(op) !op$method %in% c('GET', 'POST'),
    original$operations
  )
  stopifnot(length(selected$operations) == 14L, length(excluded) == 5L)
  namespace <- readLines(file.path(root, 'NAMESPACE'))
  definitions <- unlist(lapply(c('pet', 'store', 'user'), function(group) {
    names(getFromNamespace('tg_find_function_defs_in_file', 'specmill')(
      file.path(root, 'R', paste0(group, '.R'))
    ))
  }))
  for (op in retained) {
    stopifnot(
      op$name %in% definitions,
      paste0('export(', op$name, ')') %in% namespace,
      file.exists(file.path(root, 'man', paste0(op$name, '.Rd')))
    )
  }
  for (op in excluded) {
    stopifnot(
      !op$name %in% definitions,
      !paste0('export(', op$name, ')') %in% namespace,
      !file.exists(file.path(root, 'man', paste0(op$name, '.Rd')))
    )
  }
  before <- hashes()
  run('check')
  run('apply')
  stopifnot(identical(before, hashes()))
  for (i in seq_along(policies)) {
    writeLines(saved[[i]], policies[[i]])
  }
  restored <- run('apply')
  stopifnot(length(restored$operations) == 19L)
  run('check')
  project_path <- file.path(root, 'specmill.yml')
  project <- yaml::read_yaml(project_path, handlers = list(seq = function(x) x))
  project$selection <- list(
    methods = list('GET', 'POST'),
    exclude = list('^/pet/findByTags$')
  )
  project$defaults$docs <- list(return = 'Decoded API response.')
  yaml::write_yaml(project, project_path)
  pet_path <- file.path(root, 'apis/pet.yml')
  pet <- yaml::read_yaml(pet_path, handlers = list(seq = function(x) x))
  pet$selection$methods <- list('GET', 'DELETE') # DELETE cannot override the root limit.
  yaml::write_yaml(pet, pet_path)
  resolved <- specmill::load_project(root)
  stopifnot(
    identical(resolved$services$pet$policy$methods, 'GET'),
    resolved$services$pet$defaults$docs$return == 'Decoded API response.',
    resolved$services$pet$defaults$docs$tags$family == 'pet endpoints'
  )
  before <- hashes()
  preview <- run('plan')
  stopifnot(
    identical(before, hashes()),
    length(preview$operations) == 10L,
    length(preview$excluded) == 9L
  )
  printed <- paste(capture.output(print(preview)), collapse = '\n')
  stopifnot(all(vapply(
    c(
      'Prohibited by project methods',
      'Prohibited by service methods',
      'Matches project exclusion',
      'Files to remove'
    ),
    grepl,
    logical(1),
    x = printed,
    fixed = TRUE
  )))
  run('apply')
  run('check')
  for (selection in list(
    list(methods = 'get'),
    list(exclude = list('[')),
    list(include = list('GET /pet'))
  )) {
    invalid <- project
    invalid$selection <- selection
    yaml::write_yaml(invalid, project_path)
    stopifnot(inherits(
      tryCatch(specmill::load_project(root), error = identity),
      'error'
    ))
  }
  yaml::write_yaml(project, project_path)
  cat(
    'Method selection: grouped wrappers, exports and help removed and restored without editing endpoint lists.\n'
  )
}
if (sys.nframe() == 0L) {
  method_selection_acceptance()
}
