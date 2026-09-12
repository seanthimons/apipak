# A frozen schema and temporary local HTTP harness, never a maintained NP client.
schema_stress_acceptance <- function() {
  schema <- system.file(
    'schema-stress/natural-products.json',
    package = 'specmill',
    mustWork = TRUE
  )
  origin <- jsonlite::read_json(system.file(
    'schema-stress/natural-products-origin.json',
    package = 'specmill'
  ))
  stopifnot(identical(
    digest::digest(file = schema, algo = 'sha256'),
    origin$sha256
  ))
  document <- jsonlite::read_json(schema)
  stopifnot(
    document$openapi == '3.1.0',
    document$servers[[1L]]$url == '/latest',
    paste0(
      sub('/latest/openapi.json$', '', origin$source),
      document$servers[[1L]]$url
    ) ==
      'https://api.naturalproducts.net/latest'
  )
  parsed <- specmill::read_operations(schema)
  status <- vapply(parsed$inventory, `[[`, character(1), 'status')
  stopifnot(
    length(status) == 43L,
    sum(status == 'selected') == 33L,
    sum(status == 'unsupported') == 10L,
    length(parsed$diagnostics) == 10L
  )
  reasons <- setNames(
    vapply(
      parsed$inventory,
      function(x) if (is.null(x$reason)) '' else x$reason,
      character(1)
    ),
    vapply(parsed$inventory, `[[`, character(1), 'key')
  )
  stopifnot(
    reasons[['POST /chem/standardize']] == 'Unsupported body media type',
    reasons[['POST /convert/cdx-to-mol']] == 'Unsupported body media type',
    reasons[['POST /ocsr/process-upload']] == 'Unsupported body media type',
    reasons[['POST /convert/batch']] == '',
    reasons[['GET /chem/tanimoto']] == 'Unsupported parameter composition',
    reasons[['GET /depict/2D_enhanced']] == 'Unsupported parameter composition'
  )
  stopifnot(all(
    c('application/json', 'image/svg+xml') %in%
      names(
        document$paths[['/depict/2D_enhanced']]$get$responses[['200']]$content
      )
  ))
  port_file <- tempfile('stress-port-')
  request_file <- tempfile('stress-request-')
  server <- callr::r_bg(
    function(port_file, request_file) {
      port <- httpuv::randomPort()
      server <- httpuv::startServer(
        '127.0.0.1',
        port,
        list(call = function(request) {
          saveRDS(
            list(
              method = request$REQUEST_METHOD,
              path = request$PATH_INFO,
              query = request$QUERY_STRING,
              body = rawToChar(request$rook.input$read())
            ),
            request_file
          )
          body <- if (request$PATH_INFO == '/latest/chem/HOSEcode') {
            '{"hose_codes":["fixture"]}'
          } else if (request$PATH_INFO == '/latest/ocsr/process') {
            '{"message":"Success","reference":"fixture","smiles":"CCO"}'
          } else {
            '{"id":1,"label":"fixture","classification_status":"Done","number_of_elements":0,"number_of_pages":0,"invalid_entities":[],"entities":[]}'
          }
          list(
            status = 200L,
            headers = list('Content-Type' = 'application/json'),
            body = body
          )
        })
      )
      on.exit(server$stop(), add = TRUE)
      writeLines(as.character(port), port_file)
      repeat {
        httpuv::service(100)
      }
    },
    args = list(port_file, request_file),
    supervise = TRUE
  )
  on.exit(server$kill(), add = TRUE)
  deadline <- Sys.time() + 20
  while (
    !file.exists(port_file) && server$is_alive() && Sys.time() < deadline
  ) {
    Sys.sleep(0.05)
  }
  stopifnot(file.exists(port_file))
  root <- tempfile('schema-stress-')
  specmill::initialize_client(
    root,
    schema,
    package = 'schemastress',
    group_by = 'none',
    title = 'Temporary Schema Stress Harness',
    author = list(
      given = 'Test',
      family = 'Maintainer',
      email = 'maintainer@example.org'
    ),
    license = 'MIT + file LICENSE',
    base_url = paste0('http://127.0.0.1:', readLines(port_file), '/latest')
  )
  hashes <- function() {
    tools::md5sum(list.files(
      root,
      recursive = TRUE,
      all.files = TRUE,
      full.names = TRUE
    ))
  }
  before <- hashes()
  fails <- function(expr) {
    stopifnot(inherits(
      tryCatch(
        {
          force(expr)
          NULL
        },
        error = identity
      ),
      'error'
    ))
  }
  fails(specmill::generate_client(
    root,
    config = 'specmill.yml',
    mode = 'apply'
  ))
  stopifnot(identical(before, hashes()))
  service_path <- file.path(root, 'apis/default.yml')
  service <- yaml::read_yaml(service_path)
  service$schemas$files <- as.list(service$schemas$files)
  selected <- c(
    '/chem/HOSEcode',
    '/chem/classyfire/{jobid}/result',
    '/ocsr/process'
  )
  service$selection <- list(
    exclude = as.list(paste0(
      '^\\Q',
      setdiff(names(document$paths), selected),
      '\\E$'
    ))
  )
  service$names <- list(
    'GET /chem/HOSEcode' = 'hose_code',
    'GET /chem/classyfire/{jobid}/result' = 'job_result',
    'POST /ocsr/process' = 'process_image'
  )
  yaml::write_yaml(service, service_path)
  generated <- specmill::generate_client(
    root,
    config = 'specmill.yml',
    mode = 'apply'
  )
  stopifnot(length(generated$operations) == 3L, !length(generated$diagnostics))
  before <- hashes()
  specmill::generate_client(root, config = 'specmill.yml', mode = 'check')
  specmill::generate_client(root, config = 'specmill.yml', mode = 'apply')
  stopifnot(identical(before, hashes()))
  runtime <- new.env(parent = baseenv())
  for (file in list.files(file.path(root, 'R'), '\\.R$', full.names = TRUE)) {
    sys.source(file, runtime)
  }
  stopifnot(identical(
    runtime$hose_code(
      'C/C=C\\C',
      spheres = 0L,
      toolkit = NULL,
      ringsize = FALSE
    ),
    list(hose_codes = list('fixture'))
  ))
  request <- readRDS(request_file)
  stopifnot(
    request$method == 'GET',
    request$path == '/latest/chem/HOSEcode',
    request$query == '?smiles=C%2FC%3DC%5CC&spheres=0&ringsize=FALSE',
    request$body == ''
  )
  before_request <- tools::md5sum(request_file)
  fails(runtime$hose_code('CCO'))
  stopifnot(identical(before_request, tools::md5sum(request_file)))
  stopifnot(identical(
    runtime$job_result('job/a b'),
    list(
      id = 1L,
      label = 'fixture',
      classification_status = 'Done',
      number_of_elements = 0L,
      number_of_pages = 0L,
      invalid_entities = list(),
      entities = list()
    )
  ))
  stopifnot(
    readRDS(request_file)$path == '/latest/chem/classyfire/job%2Fa%20b/result'
  )
  body <- list(
    path = '/server-only/missing-image.png',
    reference = 'fixture',
    img = 'ZmFrZQ==',
    hand_drawn = FALSE
  )
  stopifnot(
    !file.exists(body$path),
    identical(
      runtime$process_image(body),
      list(message = 'Success', reference = 'fixture', smiles = 'CCO')
    )
  )
  request <- readRDS(request_file)
  stopifnot(
    request$method == 'POST',
    request$path == '/latest/ocsr/process',
    identical(jsonlite::fromJSON(request$body, simplifyVector = FALSE), body)
  )
  cat(
    'Schema stress: 43 visible operations, 33 supported, 10 diagnosed; three local HTTP contracts, encoding, zero/false, omission, server-side path and successful JSON returns passed.\n'
  )
}
if (sys.nframe() == 0L) {
  schema_stress_acceptance()
}
