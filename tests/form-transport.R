form_transport_acceptance <- function() {
  source(
    if (file.exists('tests/native-transport.R')) {
      'tests/native-transport.R'
    } else {
      'native-transport.R'
    }
  )
  native_transport_acceptance(function(runtime, root) {
    schema <- tempfile(fileext = '.json')
    file <- tempfile()
    on.exit(unlink(c(schema, file)), add = TRUE)
    writeBin(as.raw(c(0, 1, 127, 255)), file)
    document <- list(
      openapi = '3.0.3',
      info = list(title = 'Forms', version = '1'),
      paths = list(
        '/url' = list(
          post = list(
            operationId = 'submit_url',
            requestBody = list(
              required = TRUE,
              content = list(
                'application/x-www-form-urlencoded' = list(
                  schema = list(
                    type = 'object',
                    required = list('title'),
                    properties = list(
                      title = list(type = 'string'),
                      tags = list(type = 'array', items = list(type = 'string'))
                    )
                  ),
                  encoding = list(tags = list(style = 'form', explode = TRUE))
                )
              )
            ),
            responses = list('200' = list(description = 'OK'))
          )
        ),
        '/multi' = list(
          post = list(
            operationId = 'submit_multipart',
            requestBody = list(
              required = TRUE,
              content = list(
                'multipart/form-data' = list(
                  schema = list(
                    type = 'object',
                    required = list('title', 'raw', 'files'),
                    properties = list(
                      title = list(type = 'string'),
                      raw = list(type = 'string', format = 'binary'),
                      files = list(
                        type = 'array',
                        items = list(type = 'string', format = 'binary')
                      ),
                      metadata = list(
                        type = 'object',
                        properties = list(id = list(type = 'integer'))
                      )
                    )
                  ),
                  encoding = list(
                    metadata = list(contentType = 'application/json')
                  )
                )
              )
            ),
            responses = list('200' = list(description = 'OK'))
          )
        ),
        '/both' = list(
          post = list(
            operationId = 'submit_selected',
            requestBody = list(
              required = TRUE,
              content = list(
                'application/json' = list(schema = list(type = 'object')),
                'application/x-www-form-urlencoded' = list(
                  schema = list(
                    type = 'object',
                    properties = list(value = list(type = 'string'))
                  )
                )
              )
            ),
            responses = list('200' = list(description = 'OK'))
          )
        )
      )
    )
    jsonlite::write_json(document, schema, auto_unbox = TRUE)
    parsed <- specmill::read_operations(schema)
    selected <- specmill::read_operations(
      schema,
      list(
        body_media_overrides = list(
          'POST /both' = 'application/x-www-form-urlencoded'
        )
      )
    )
    unsupported <- function(mutator) {
      bad <- document
      bad <- mutator(bad)
      jsonlite::write_json(bad, schema, auto_unbox = TRUE)
      result <- specmill::read_operations(schema)
      stopifnot(length(result$diagnostics) == 1L)
    }
    unsupported(function(bad) {
      bad$paths[['/url']]$post$requestBody$content[[
        'application/x-www-form-urlencoded'
      ]]$encoding$title$headers <- list(
        'X-Part' = list(schema = list(type = 'string'))
      )
      bad
    })
    unsupported(function(bad) {
      bad$paths[['/url']]$post$requestBody$content[[
        'application/x-www-form-urlencoded'
      ]]$encoding$title$style <- 'deepObject'
      bad
    })
    unsupported(function(bad) {
      bad$paths[['/url']]$post$requestBody$content[[
        'application/x-www-form-urlencoded'
      ]]$schema$properties$title <- list(
        type = 'object',
        properties = list(value = list(type = 'string'))
      )
      bad
    })
    unsupported(function(bad) {
      bad$paths[['/url']]$post$requestBody$content[[
        'application/x-www-form-urlencoded'
      ]]$schema$additionalProperties <- list(type = 'string')
      bad
    })
    jsonlite::write_json(document, schema, auto_unbox = TRUE)
    stopifnot(
      !length(parsed$diagnostics),
      identical(
        parsed$operations$submit_url$body_media,
        'application/x-www-form-urlencoded'
      ),
      identical(
        parsed$operations$submit_multipart$body_media,
        'multipart/form-data'
      ),
      identical(
        selected$operations$submit_selected$body_media,
        'application/x-www-form-urlencoded'
      )
    )
    for (operation in list(
      parsed$operations$submit_url,
      parsed$operations$submit_multipart,
      selected$operations$submit_selected
    )) {
      eval(
        parse(
          text = specmill::render_operation(
            operation,
            list(helper = 'api_request')
          )
        ),
        runtime
      )
    }
    wire <- function(result) rawToChar(as.raw(unlist(result$bytes)))
    positions <- function(raw, needle) {
      starts <- which(raw == needle[[1L]])
      starts[vapply(
        starts,
        function(start) {
          end <- start + length(needle) - 1L
          end <= length(raw) && identical(raw[start:end], needle)
        },
        logical(1)
      )]
    }
    multipart_parts <- function(result) {
      raw <- as.raw(unlist(result$bytes))
      boundary <- sub('^multipart/form-data; boundary=', '', result$type)
      marks <- positions(raw, charToRaw(paste0('--', boundary)))
      separator <- charToRaw('\r\n\r\n')
      lapply(seq_len(length(marks) - 1L), function(i) {
        start <- marks[[i]] + nchar(boundary) + 4L
        end <- marks[[i + 1L]] - 3L
        part <- raw[start:end]
        split <- positions(part, separator)[[1L]]
        list(
          headers = rawToChar(part[seq_len(split - 1L)]),
          data = part[(split + length(separator)):length(part)]
        )
      })
    }
    url <- runtime$submit_url(list(
      title = 'hello world',
      tags = list('red', 'blue')
    ))
    stopifnot(
      identical(url$type, 'application/x-www-form-urlencoded'),
      identical(wire(url), 'title=hello%20world&tags=red&tags=blue'),
      identical(
        wire(runtime$submit_url(list(title = 'only required'))),
        'title=only%20required'
      ),
      identical(
        runtime$submit_selected(list())$type,
        'application/x-www-form-urlencoded'
      ),
      identical(wire(runtime$submit_selected(list())), ''),
      identical(
        wire(runtime$submit_selected(list(value = 'chosen'))),
        'value=chosen'
      )
    )
    multi <- runtime$submit_multipart(list(
      title = 'upload',
      raw = as.raw(c(0, 1, 127, 255)),
      files = list(as.raw(c(1, 2)), curl::form_file(file, name = 'upload.bin')),
      metadata = list(id = 1L)
    ))
    parts <- multipart_parts(multi)
    file_parts <- Filter(
      function(part) grepl('name="files"', part$headers, fixed = TRUE),
      parts
    )
    raw_part <- Filter(
      function(part) grepl('name="raw"', part$headers, fixed = TRUE),
      parts
    )[[1L]]
    title_part <- Filter(
      function(part) grepl('name="title"', part$headers, fixed = TRUE),
      parts
    )[[1L]]
    metadata_part <- Filter(
      function(part) grepl('name="metadata"', part$headers, fixed = TRUE),
      parts
    )[[1L]]
    stopifnot(
      startsWith(multi$type, 'multipart/form-data; boundary='),
      length(file_parts) == 2L,
      grepl('Content-Type: text/plain', title_part$headers, fixed = TRUE),
      identical(rawToChar(title_part$data), 'upload'),
      grepl(
        'Content-Type: application/octet-stream',
        raw_part$headers,
        fixed = TRUE
      ),
      identical(raw_part$data, as.raw(c(0, 1, 127, 255))),
      grepl(
        'Content-Type: application/octet-stream',
        file_parts[[1L]]$headers,
        fixed = TRUE
      ),
      identical(file_parts[[1L]]$data, as.raw(c(1, 2))),
      identical(file_parts[[2L]]$data, as.raw(c(0, 1, 127, 255))),
      grepl('filename="upload.bin"', file_parts[[2L]]$headers, fixed = TRUE),
      grepl(
        'Content-Type: application/json',
        metadata_part$headers,
        fixed = TRUE
      ),
      identical(rawToChar(metadata_part$data), '{"id":1}')
    )
    fixtures <- specmill::operation_fixtures(parsed$operations)
    stopifnot(
      is.raw(fixtures$submit_multipart$body$raw),
      length(fixtures$submit_multipart$body$files) == 1L
    )
    empty_multipart <- list(
      name = 'empty_multipart',
      body_media = 'multipart/form-data',
      body = list(type = 'object', properties = list()),
      parameters = list()
    )
    stopifnot(inherits(
      try(
        specmill::operation_fixtures(list(empty_multipart = empty_multipart)),
        silent = TRUE
      ),
      'try-error'
    ))
    zero_array <- list(
      name = 'zero_array',
      body_media = 'application/x-www-form-urlencoded',
      body = list(
        type = 'object',
        properties = list(
          tags = list(
            type = 'array',
            minItems = 0L,
            items = list(type = 'string')
          )
        )
      ),
      parameters = list()
    )
    zero_fixture <- specmill::operation_fixtures(list(zero_array = zero_array))
    stopifnot(length(zero_fixture$zero_array$body$tags) == 1L)
    calls <- 0L
    request <- runtime$api_request
    runtime$api_request <- function(...) {
      calls <<- calls + 1L
      request(...)
    }
    fails <- function(expr) {
      stopifnot(inherits(try(force(expr), silent = TRUE), 'try-error'))
    }
    fails(runtime$submit_url())
    fails(runtime$submit_url(NULL))
    fails(runtime$submit_url(list(title = NULL)))
    fails(runtime$submit_url(list(tags = list('only optional'))))
    fails(runtime$submit_url(list(title = 'x', tags = list())))
    fails(runtime$submit_multipart(list()))
    fails(runtime$submit_multipart(list(
      title = 'x',
      raw = 'not raw',
      files = list(as.raw(1))
    )))
    stopifnot(calls == 0L)
    runtime$api_request <- request
    swagger <- tempfile(fileext = '.json')
    on.exit(unlink(swagger), add = TRUE)
    jsonlite::write_json(
      list(
        swagger = '2.0',
        info = list(title = 'Swagger forms', version = '1'),
        consumes = list('multipart/form-data'),
        paths = list(
          '/form' = list(
            post = list(
              operationId = 'swagger_form',
              parameters = list(
                list(
                  name = 'title',
                  `in` = 'formData',
                  required = TRUE,
                  type = 'string'
                ),
                list(
                  name = 'files',
                  `in` = 'formData',
                  type = 'array',
                  items = list(type = 'file'),
                  collectionFormat = 'multi'
                )
              ),
              responses = list('200' = list(description = 'OK'))
            )
          )
        )
      ),
      swagger,
      auto_unbox = TRUE
    )
    swagger_parsed <- specmill::read_operations(swagger)
    if (!length(swagger_parsed$operations)) {
      stop(swagger_parsed$diagnostics[[1L]]$reason)
    }
    swagger_op <- swagger_parsed$operations$swagger_form
    if (
      !is.character(swagger_op$body_media) ||
        length(swagger_op$body_media) != 1L
    ) {
      stop(
        'Swagger media shape: ',
        paste(capture.output(str(swagger_op$body_media)), collapse = ' ')
      )
    }
    stopifnot(
      swagger_op$body_media == 'multipart/form-data',
      identical(swagger_op$body_encoding$files$collection_format, 'multi')
    )
    swagger_bad <- jsonlite::read_json(swagger, simplifyVector = FALSE)
    swagger_bad$paths[['/form']]$post$parameters[[2L]]$collectionFormat <- 'csv'
    jsonlite::write_json(swagger_bad, swagger, auto_unbox = TRUE)
    stopifnot(length(specmill::read_operations(swagger)$diagnostics) == 1L)
    eval(
      parse(
        text = specmill::render_operation(
          swagger_op,
          list(helper = 'api_request')
        )
      ),
      runtime
    )
    swagger_wire <- runtime$swagger_form(list(
      title = 'swagger',
      files = list(as.raw(c(3, 4)))
    ))
    stopifnot(
      startsWith(swagger_wire$type, 'multipart/form-data; boundary='),
      any(vapply(
        multipart_parts(swagger_wire),
        function(part) {
          identical(part$data, as.raw(c(3, 4)))
        },
        logical(1)
      ))
    )
    cat(
      'Form transport: urlencoded, multipart binary/file/repeated parts, media selection, Swagger formData, fixtures, and preflight validation passed.\n'
    )
  })
}
if (sys.nframe() == 0L) {
  form_transport_acceptance()
}
