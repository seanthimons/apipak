audit_proving_ground <- function(root, output = 'dev/audits/proving-ground') {
  root <- normalizePath(root, winslash = '/', mustWork = TRUE)
  snapshot <- function() {
    tools::md5sum(list.files(
      root,
      recursive = TRUE,
      all.files = TRUE,
      full.names = TRUE
    ))
  }
  before <- snapshot()
  plan <- specmill::generate_client(
    root,
    config = 'specmill.yml',
    mode = 'plan'
  )
  stopifnot(identical(before, snapshot()))
  documents <- list()
  inspect_schema <- function(
    node,
    document,
    pointer,
    version,
    seen = character(),
    parameter_items = FALSE
  ) {
    findings <- list()
    add <- function(kind, location, detail) {
      findings[[length(findings) + 1L]] <<- list(
        kind = kind,
        pointer = location,
        detail = detail
      )
    }
    if (is.null(node)) {
      add('missing_schema', pointer, 'No schema supplied')
      return(findings)
    }
    if (!is.list(node)) {
      add('non_object_schema', pointer, paste(node, collapse = ', '))
      return(findings)
    }
    ref <- node[['$ref']]
    if (!is.null(ref)) {
      if (!startsWith(ref, '#/')) {
        add('external_ref', pointer, ref)
        return(findings)
      }
      if (ref %in% seen) {
        add('recursive_ref', pointer, ref)
        return(findings)
      }
      parts <- strsplit(sub('^#/', '', ref), '/', fixed = TRUE)[[1L]]
      parts <- gsub(
        '~0',
        '~',
        gsub('~1', '/', parts, fixed = TRUE),
        fixed = TRUE
      )
      target <- document
      for (part in parts) {
        target <- if (is.list(target)) target[[part]] else NULL
      }
      if (is.null(target)) {
        add('dangling_ref', pointer, ref)
        return(findings)
      }
      return(inspect_schema(
        target,
        document,
        ref,
        version,
        c(seen, ref),
        parameter_items
      ))
    }
    if (!length(node)) {
      add('unconstrained_schema', pointer, 'Empty schema object')
    }
    type <- unlist(node$type, use.names = FALSE)
    invalid <- setdiff(
      type,
      c('object', 'array', 'string', 'number', 'integer', 'boolean', 'null')
    )
    if (length(invalid)) {
      add(
        'invalid_type',
        paste0(pointer, '/type'),
        paste(invalid, collapse = ', ')
      )
    }
    if ('array' %in% type && is.null(node$items)) {
      if (
        startsWith(version, '3.0') ||
          (identical(version, '2.0') && parameter_items)
      ) {
        add(
          'missing_array_items',
          pointer,
          'Array requires items in this schema/parameter context'
        )
      } else {
        add(
          'unconstrained_array_items',
          pointer,
          'No item constraints supplied'
        )
      }
    }
    if (
      'object' %in%
        type &&
        (!length(node$properties) ||
          (!is.null(node$additionalProperties) &&
            !isFALSE(node$additionalProperties)))
    ) {
      add(
        'open_object',
        pointer,
        if (isFALSE(node$additionalProperties)) {
          'Closed empty object'
        } else {
          'Open object or dictionary'
        }
      )
    }
    for (field in intersect(c('oneOf', 'anyOf', 'allOf'), names(node))) {
      add('composition', paste0(pointer, '/', field), field)
      for (i in seq_along(node[[field]])) {
        findings <- c(
          findings,
          inspect_schema(
            node[[field]][[i]],
            document,
            paste0(pointer, '/', field, '/', i - 1L),
            version,
            seen
          )
        )
      }
    }
    for (name in names(node$properties)) {
      findings <- c(
        findings,
        inspect_schema(
          node$properties[[name]],
          document,
          paste0(pointer, '/properties/', name),
          version,
          seen
        )
      )
    }
    if (!is.null(node$items)) {
      findings <- c(
        findings,
        inspect_schema(
          node$items,
          document,
          paste0(pointer, '/items'),
          version,
          seen,
          parameter_items
        )
      )
    }
    if (is.list(node$additionalProperties)) {
      findings <- c(
        findings,
        inspect_schema(
          node$additionalProperties,
          document,
          paste0(pointer, '/additionalProperties'),
          version,
          seen
        )
      )
    }
    findings
  }
  rows <- lapply(plan$diagnostics, function(diagnostic) {
    source <- diagnostic$source
    if (is.null(documents[[source]])) {
      documents[[source]] <<- jsonlite::read_json(source)
    }
    document <- documents[[source]]
    version <- document$openapi %||% document$swagger
    method <- sub(' .*', '', diagnostic$key)
    path <- sub('^[^ ]+ ', '', diagnostic$key)
    item <- document$paths[[path]]
    operation <- item[[tolower(method)]]
    pointer <- paste0(
      '#/paths/',
      gsub('/', '~1', gsub('~', '~0', path, fixed = TRUE), fixed = TRUE),
      '/',
      tolower(method)
    )
    findings <- list()
    query_binary <- FALSE
    for (parameter in c(item$parameters, operation$parameters)) {
      if (!is.null(parameter[['$ref']])) {
        parameter <- getFromNamespace('local_ref', 'specmill')(
          parameter,
          document
        )
      }
      at <- paste0(
        pointer,
        '/parameters/',
        parameter[['in']],
        ' ',
        parameter$name
      )
      findings <- c(
        findings,
        inspect_schema(
          parameter$schema %||% parameter,
          document,
          at,
          version,
          parameter_items = identical(version, '2.0') &&
            parameter[['in']] != 'body'
        )
      )
      if (
        identical(parameter[['in']], 'query') &&
          identical(parameter$schema$items$format, 'binary')
      ) {
        query_binary <- TRUE
      }
    }
    content <- operation$requestBody$content
    if (!is.null(operation$requestBody[['$ref']])) {
      content <- getFromNamespace('local_ref', 'specmill')(
        operation$requestBody,
        document
      )$content
    }
    for (media in names(content)) {
      findings <- c(
        findings,
        inspect_schema(
          content[[media]]$schema,
          document,
          paste0(pointer, '/requestBody/content/', media, '/schema'),
          version
        )
      )
    }
    kinds <- vapply(findings, `[[`, character(1), 'kind')
    defects <- kinds %in%
      c(
        'invalid_type',
        'missing_array_items',
        'dangling_ref',
        'non_object_schema'
      )
    classification <- if (any(defects)) 'schema_defect' else 'capability_gap'
    review <- c(
      if (query_binary) 'Binary files declared in query; verify wire contract',
      if (method == 'GET' && !is.null(operation$requestBody)) {
        'GET request body; verify intended contract'
      },
      if (
        any(
          kinds %in%
            c(
              'unconstrained_schema',
              'unconstrained_array_items',
              'missing_schema'
            )
        )
      ) {
        'Unconstrained/missing schema; do not infer types from examples'
      }
    )
    evidence <- findings[
      if (any(defects)) defects else rep(TRUE, length(findings))
    ]
    evidence <- unique(vapply(
      evidence,
      function(finding) {
        paste(finding$kind, finding$pointer, finding$detail, sep = ': ')
      },
      character(1)
    ))
    data.frame(
      api = sub('\\.json$', '', basename(source)),
      service = diagnostic$service,
      method = method,
      path = path,
      version = version,
      reason = diagnostic$reason,
      classification = classification,
      review = paste(review, collapse = '; '),
      findings = paste(unique(kinds), collapse = '; '),
      evidence = paste(evidence, collapse = ' | '),
      stringsAsFactors = FALSE
    )
  })
  diagnostics <- do.call(rbind, rows)
  stopifnot(
    !anyDuplicated(paste(
      diagnostics$service,
      diagnostics$method,
      diagnostics$path
    ))
  )
  dir.create(output, recursive = TRUE, showWarnings = FALSE)
  utils::write.csv(
    diagnostics,
    file.path(output, 'operations.csv'),
    row.names = FALSE,
    na = ''
  )
  inputs <- list.files(file.path(root, 'schema'), '\\.json$', full.names = TRUE)
  hashes <- vapply(
    inputs,
    function(path) digest::digest(file = path, algo = 'sha256'),
    character(1)
  )
  utils::write.csv(
    data.frame(schema = basename(inputs), sha256 = hashes),
    file.path(output, 'schemas.csv'),
    row.names = FALSE
  )
  summary <- aggregate(
    list(operations = rep(1L, nrow(diagnostics))),
    diagnostics[c('classification', 'reason', 'method')],
    sum
  )
  utils::write.csv(summary, file.path(output, 'summary.csv'), row.names = FALSE)
  cat(
    length(plan$operations),
    'renderable operations;',
    nrow(diagnostics),
    'diagnostics\n'
  )
  print(table(diagnostics$classification))
  print(summary, row.names = FALSE)
  invisible(list(plan = plan, diagnostics = diagnostics))
}
