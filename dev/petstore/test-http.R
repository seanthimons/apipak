# Independently specified wire contracts; every endpoint runs against localhost.
testthat::test_that('all endpoint functions send the expected HTTP requests', {
  run_contracts <- function() {
    port_file <- tempfile('petstore-port-')
    server <- callr::r_bg(
      function(port_file) {
        port <- httpuv::randomPort()
        server <- httpuv::startServer(
          '127.0.0.1',
          port,
          list(call = function(req) {
            if (req$PATH_INFO == '/api/v3/user/missing') {
              return(list(
                status = 404L,
                headers = list('Content-Type' = 'text/plain'),
                body = 'Not found'
              ))
            }
            bytes <- req$rook.input$read()
            list(
              status = 200L,
              headers = list('Content-Type' = 'application/json'),
              body = jsonlite::toJSON(
                list(
                  method = req$REQUEST_METHOD,
                  path = req$PATH_INFO,
                  query = sub('^\\?', '', req$QUERY_STRING),
                  body = as.list(as.integer(bytes)),
                  type = req$CONTENT_TYPE,
                  api_key = req$HTTP_API_KEY,
                  accept = req$HTTP_ACCEPT
                ),
                auto_unbox = TRUE,
                null = 'null'
              )
            )
          })
        )
        on.exit(server$stop())
        writeLines(as.character(port), port_file)
        repeat {
          httpuv::service(100)
        }
      },
      args = list(port_file),
      supervise = TRUE
    )
    on.exit(server$kill(), add = TRUE)
    for (i in seq_len(200L)) {
      if (file.exists(port_file)) {
        break
      }
      if (!server$is_alive()) {
        server$get_result()
      }
      Sys.sleep(0.05)
    }
    stopifnot(file.exists(port_file))
    old <- options(
      petstoretrial.base_url = paste0(
        'http://127.0.0.1:',
        readLines(port_file),
        '/api/v3'
      )
    )
    on.exit(options(old), add = TRUE)
    pet <- list(name = 'Miso', photoUrls = list())
    user <- list(username = 'alice')
    order <- list(petId = 7L, quantity = 0L, complete = FALSE)
    case <- function(
      inputs,
      method,
      path,
      query = '',
      body = NULL,
      raw = FALSE,
      api_key = NULL
    ) {
      list(
        inputs = inputs,
        method = method,
        path = paste0('/api/v3', path),
        query = query,
        body = body,
        raw = raw,
        api_key = api_key
      )
    }
    cases <- list(
      pet_create = case(list(body = pet), 'POST', '/pet', body = pet),
      pet_update = case(list(body = pet), 'PUT', '/pet', body = pet),
      pet_find_by_status = case(
        list(status = 'available'),
        'GET',
        '/pet/findByStatus',
        'status=available'
      ),
      pet_find_by_tags = case(
        list(tags = c('a b', 'x/y')),
        'GET',
        '/pet/findByTags',
        'tags=a%20b&tags=x%2Fy'
      ),
      pet_get = case(list(pet_id = 7L), 'GET', '/pet/7'),
      pet_update_fields = case(
        list(pet_id = 7L, name = 'Miso', status = 'sold'),
        'POST',
        '/pet/7',
        'name=Miso&status=sold'
      ),
      pet_delete = case(
        list(pet_id = 7L, api_key = 'fixture-only'),
        'DELETE',
        '/pet/7',
        api_key = 'fixture-only'
      ),
      pet_upload_image = case(
        list(pet_id = 7L, image = as.raw(c(0, 255)), metadata = 'a b'),
        'POST',
        '/pet/7/uploadImage',
        'additionalMetadata=a%20b',
        body = as.raw(c(0, 255)),
        raw = TRUE
      ),
      store_inventory = case(list(), 'GET', '/store/inventory'),
      store_order_create = case(
        list(body = order),
        'POST',
        '/store/order',
        body = order
      ),
      store_order_get = case(list(order_id = 7L), 'GET', '/store/order/7'),
      store_order_delete = case(
        list(order_id = 7L),
        'DELETE',
        '/store/order/7'
      ),
      user_create = case(list(body = user), 'POST', '/user', body = user),
      user_create_many = case(
        list(body = list(user)),
        'POST',
        '/user/createWithList',
        body = list(user)
      ),
      user_login = case(
        list(username = 'alice', password = 'fixture-only'),
        'GET',
        '/user/login',
        'username=alice&password=fixture-only'
      ),
      user_logout = case(list(), 'GET', '/user/logout'),
      user_get = case(list(username = 'a/b'), 'GET', '/user/a%2Fb'),
      user_update = case(
        list(username = 'alice', body = user),
        'PUT',
        '/user/alice',
        body = user
      ),
      user_delete = case(list(username = 'alice'), 'DELETE', '/user/alice')
    )
    testthat::expect_setequal(
      getNamespaceExports('petstoretrial'),
      names(cases)
    )
    for (name in names(cases)) {
      expected <- cases[[name]]
      actual <- do.call(
        getExportedValue('petstoretrial', name),
        expected$inputs
      )
      for (field in c('method', 'path', 'query', 'api_key')) {
        testthat::expect_identical(
          actual[[field]],
          expected[[field]],
          info = paste(name, field)
        )
      }
      testthat::expect_identical(actual$accept, 'application/json', info = name)
      bytes <- as.raw(unlist(actual$body))
      if (is.null(expected$body)) {
        testthat::expect_identical(length(bytes), 0L, info = name)
      } else if (expected$raw) {
        testthat::expect_identical(bytes, expected$body, info = name)
        testthat::expect_identical(
          actual$type,
          'application/octet-stream',
          info = name
        )
      } else {
        testthat::expect_identical(
          jsonlite::fromJSON(rawToChar(bytes), simplifyVector = FALSE),
          expected$body,
          info = name
        )
        testthat::expect_match(actual$type, '^application/json', info = name)
      }
    }
    testthat::expect_error(
      petstoretrial::user_get('missing'),
      class = 'httr2_http_404'
    )
    testthat::expect_error(
      petstoretrial::pet_upload_image(7L, 'not raw'),
      'raw vector'
    )
    # Explicit mapping supports both singleton and multiple query values.
    testthat::expect_identical(
      petstoretrial::pet_find_by_tags('solo')$query,
      'tags=solo'
    )
  }
  run_contracts()
})
