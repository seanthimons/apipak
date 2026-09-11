read_operations <- function(files, policy = list()) {
  operations <- list()
  diagnostics <- list()
  inventory <- list()
  methods <- policy$methods %or%
    c('GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'HEAD', 'OPTIONS', 'TRACE')
  patterns <- policy$exclude %or% character()
  include <- policy$include
  for (pattern in patterns) {
    stringr::str_detect('', pattern)
  }
  for (file in files) {
    first_operation <- length(operations) + 1L
    document <- jsonlite::fromJSON(file, simplifyVector = FALSE)
    source_hash <- unname(tools::md5sum(file))
    security_schemes <- lapply(
      document$components$securitySchemes %or%
        document$securityDefinitions %or%
        list(),
      local_ref,
      document = document
    )
    version <- document$openapi %or% document$swagger
    if (is.null(version) || !grepl('^(3\\.[01]\\.|2\\.0$)', version)) {
      stop('Unsupported schema version in ', file, call. = FALSE)
    }
    if (!is.list(document$paths) || is.null(names(document$paths))) {
      stop('Missing paths: ', file)
    }
    for (path in names(document$paths)) {
      item <- document$paths[[path]]
      for (method in intersect(
        names(item),
        c('get', 'post', 'put', 'patch', 'delete', 'head', 'options', 'trace')
      )) {
        key <- paste(toupper(method), path)
        id <- paste(policy$service %or% 'default', key)
        selected <- toupper(method) %in%
          methods &&
          (is.null(include) || key %in% include) &&
          !any(vapply(
            patterns,
            function(pattern) stringr::str_detect(path, pattern),
            logical(1)
          ))
        record <- list(
          id = id,
          key = key,
          service = policy$service %or% 'default',
          method = toupper(method),
          path = path,
          source = file,
          source_hash = source_hash,
          status = if (selected) 'selected' else 'excluded',
          reason = if (selected) '' else 'Explicit selection policy'
        )
        inventory[[length(inventory) + 1L]] <- record
        if (!selected) {
          next
        }
        operation <- tryCatch(
          {
            if (!startsWith(path, '/') || grepl('[\r\n]', path)) {
              stop('Invalid route')
            }
            op <- item[[method]]
            if (
              ('security' %in% names(op) && !is.list(op$security)) ||
                ('security' %in% names(document) && !is.list(document$security))
            ) {
              stop('Security requirements must be arrays, not null or scalars')
            }
            transport_diagnostics <- character()
            unsupported <- function(reason) {
              transport_diagnostics <<- unique(c(transport_diagnostics, reason))
            }
            params <- lapply(
              c(item$parameters, op$parameters),
              local_ref,
              document = document
            )
            ids <- vapply(
              params,
              function(p) paste(p[['in']], p$name),
              character(1)
            )
            params <- params[!duplicated(ids, fromLast = TRUE)]
            body <- op$requestBody
            body_present <- !is.null(body)
            body_required <- FALSE
            body_media <- 'application/json'
            if (startsWith(version, '2.')) {
              bodies <- Filter(function(p) identical(p[['in']], 'body'), params)
              if (length(bodies) > 1L) {
                stop('Multiple body parameters')
              }
              body_required <- length(bodies) == 1L &&
                isTRUE(bodies[[1]]$required)
              body_present <- length(bodies) == 1L
              body <- if (length(bodies)) bodies[[1]]$schema else NULL
              params <- Filter(
                function(p) !identical(p[['in']], 'body'),
                params
              )
            } else if (!is.null(body)) {
              body <- local_ref(body, document)
              body_required <- isTRUE(body$required)
              if ('application/json' %in% names(body$content)) {
                body_media <- 'application/json'
              } else if ('application/octet-stream' %in% names(body$content)) {
                body_media <- 'application/octet-stream'
              } else {
                stop('Unsupported body media type')
              }
              body <- body$content[[body_media]]$schema
            }
            params <- lapply(params, function(p) {
              location <- p[['in']]
              if (
                length(location) != 1L ||
                  !location %in%
                    c('path', 'query', 'header', 'cookie', 'formData')
              ) {
                stop('Invalid parameter location')
              }
              if (!location %in% c('path', 'query', 'header')) {
                unsupported('Unsupported parameter location')
              }
              if (
                !is.character(p$name) || length(p$name) != 1L || !nzchar(p$name)
              ) {
                stop('Invalid parameter name')
              }
              schema <- p$schema %or% p
              if (is.null(p$schema)) {
                schema$required <- NULL
              }
              schema <- input_schema(schema, document)
              if (
                length(schema$type) != 1L ||
                  (!schema$type %in%
                    c('string', 'integer', 'number', 'boolean') &&
                    !(location == 'query' &&
                      identical(schema$type, 'array') &&
                      identical(schema$items$type, 'string')))
              ) {
                unsupported('Unsupported parameter type')
              }
              style <- if (location %in% c('path', 'header')) {
                'simple'
              } else {
                'form'
              }
              if (
                !is.null(p$style) &&
                  p$style != style ||
                  !is.null(p$content) ||
                  isTRUE(p$allowReserved)
              ) {
                unsupported('Unsupported parameter serialization')
              }
              if (
                identical(schema$type, 'array') && startsWith(version, '2.')
              ) {
                unsupported('Unsupported Swagger array serialization')
              }
              if (location == 'path' && !isTRUE(p$required)) {
                stop('Path parameter must be required')
              }
              list(
                name = p$name,
                location = location,
                required = isTRUE(p$required),
                schema = schema,
                style = p$style %or% style,
                explode = p$explode %or% (location == 'query')
              )
            })
            if (body_present) {
              body <- input_schema(body, document)
              if (
                body_media == 'application/octet-stream' &&
                  !(identical(body$type, 'string') &&
                    identical(body$format, 'binary'))
              ) {
                unsupported('Unsupported binary body schema')
              }
              body <- tryCatch(
                supported_body(body, document),
                error = function(e) {
                  unsupported(conditionMessage(e))
                  body
                }
              )
            }
            candidate <- op$operationId
            if (
              is.null(candidate) || !identical(make.names(candidate), candidate)
            ) {
              candidate <- make.names(paste(
                method,
                gsub('[^A-Za-z0-9]+', '_', path),
                sep = '_'
              ))
            }
            name <- policy$names[[key]] %or% candidate
            if (!identical(make.names(name), name) || name %in% c('...', '')) {
              stop('Invalid operation name')
            }
            list(
              key = key,
              id = paste(policy$service %or% 'default', key),
              service = policy$service %or% 'default',
              operationId = op$operationId,
              name = name,
              method = toupper(method),
              path = path,
              parameters = params,
              body = body,
              body_required = body_required,
              body_media = body_media,
              security = if ('security' %in% names(op)) {
                op$security
              } else {
                document$security
              },
              security_schemes = security_schemes,
              source = normalizePath(file, winslash = '/'),
              source_hash = source_hash,
              schema_version = version,
              transport_diagnostics = transport_diagnostics,
              source_operation = op,
              response = op$responses,
              summary = op$summary %or% name
            )
          },
          error = function(e) {
            diagnostics[[length(diagnostics) + 1L]] <<- list(
              id = id,
              service = policy$service %or% 'default',
              key = key,
              source = file,
              status = 'unsupported',
              reason = conditionMessage(e)
            )
            NULL
          }
        )
        if (!is.null(operation)) {
          operations[[length(operations) + 1L]] <- operation
          if (length(operation$transport_diagnostics)) {
            diagnostics[[length(diagnostics) + 1L]] <- list(
              id = id,
              service = policy$service %or% 'default',
              key = key,
              source = file,
              status = 'unsupported',
              reason = paste(operation$transport_diagnostics, collapse = '; ')
            )
          }
        }
      }
    }
    if (length(operations) >= first_operation) {
      indices <- seq.int(first_operation, length(operations))
      indices <- indices[vapply(
        operations[indices],
        function(op) !length(op$transport_diagnostics),
        logical(1)
      )]
      if (length(indices)) {
        operations[indices] <- endpoint_records(document, operations[indices])
      }
    }
  }
  ids <- vapply(operations, `[[`, character(1), 'id')
  duplicate_ids <- unique(ids[duplicated(ids)])
  for (id in duplicate_ids) {
    group <- operations[ids == id]
    contract <- function(x) x[setdiff(names(x), c('source', 'source_hash'))]
    if (
      !all(vapply(
        group[-1L],
        function(x) identical(contract(x), contract(group[[1L]])),
        logical(1)
      ))
    ) {
      stop(
        'Conflicting duplicate operation ',
        id,
        ' in ',
        paste(vapply(group, `[[`, character(1), 'source'), collapse = ', ')
      )
    }
  }
  operations <- operations[!duplicated(ids)]
  indexed_keys <- vapply(inventory, `[[`, character(1), 'key')
  unknown <- setdiff(
    union(union(names(policy$names), policy$override_keys), include),
    indexed_keys
  )
  if (length(unknown)) {
    stop('Unknown operation override: ', paste(unknown, collapse = ', '))
  }
  operation_names <- vapply(operations, `[[`, character(1), 'name')
  if (anyDuplicated(operation_names)) {
    stop('Operation name collision; supply reviewed name overrides')
  }
  names(operations) <- operation_names
  unsupported <- vapply(diagnostics, `[[`, character(1), 'id')
  inventory <- lapply(inventory, function(x) {
    if (x$id %in% unsupported) {
      x$status <- 'unsupported'
      x$reason <- diagnostics[[match(x$id, unsupported)]]$reason
    }
    x
  })
  supported <- vapply(
    operations,
    function(op) !length(op$transport_diagnostics),
    logical(1)
  )
  list(
    operations = operations[supported],
    unsupported_operations = operations[!supported],
    diagnostics = diagnostics,
    inventory = inventory
  )
}

compare_operations <- function(old, new) {
  identity <- function(op) {
    paste(op$service %or% basename(op$source %or% ''), op$key)
  }
  old <- setNames(
    old$operations,
    vapply(old$operations, identity, character(1))
  )
  new <- setNames(
    new$operations,
    vapply(new$operations, identity, character(1))
  )
  out <- list()
  add <- function(key, status, reason) {
    out[[length(out) + 1L]] <<- list(
      key = key,
      status = status,
      reason = reason
    )
  }
  for (key in setdiff(names(old), names(new))) {
    add(key, 'breaking', 'Operation removed')
  }
  for (key in setdiff(names(new), names(old))) {
    add(key, 'added', 'Operation added')
  }
  for (key in intersect(names(old), names(new))) {
    a <- old[[key]]
    b <- new[[key]]
    ids <- function(ps) {
      setNames(
        ps,
        vapply(ps, function(p) paste(p$location, p$name), character(1))
      )
    }
    ap <- ids(a$parameters)
    bp <- ids(b$parameters)
    for (id in setdiff(names(bp), names(ap))) {
      add(
        key,
        if (isTRUE(bp[[id]]$required)) 'breaking' else 'added',
        paste('Parameter added:', id)
      )
    }
    if (length(setdiff(names(ap), names(bp)))) {
      add(key, 'breaking', 'Parameter removed')
    }
    for (id in intersect(names(ap), names(bp))) {
      if (!identical(ap[[id]], bp[[id]])) {
        add(key, 'review', paste('Parameter contract changed:', id))
      }
    }
    if (
      !identical(a$body, b$body) || !identical(a$body_required, b$body_required)
    ) {
      add(key, 'review', 'Body changed')
    }
    if (!identical(a$response, b$response)) {
      add(key, 'unknown', 'Response compatibility is not classified')
    }
    if (
      !identical(a$security, b$security) ||
        !identical(a$security_schemes, b$security_schemes)
    ) {
      add(key, 'review', 'Authentication requirements changed')
    }
  }
  out
}
