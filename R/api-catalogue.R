schema_identity <- function(document) {
  canonical <- function(x) {
    if (!is.list(x)) {
      return(x)
    }
    if (!is.null(names(x))) {
      x <- x[sort(names(x), method = 'radix')]
    }
    lapply(x, canonical)
  }
  digest::digest(canonical(document), algo = 'sha256')
}

schema_server <- function(document, origin = '') {
  urls <- if (identical(document$swagger, '2.0')) {
    if (!is.null(document$host)) {
      paste0(
        (document$schemes %or% list('https'))[[1L]],
        '://',
        document$host,
        document$basePath %or% '/'
      )
    } else {
      document$basePath %or% ''
    }
  } else {
    vapply(
      document$servers %or% list(),
      function(server) {
        url <- server$url %or% ''
        for (name in names(server$variables)) {
          value <- server$variables[[name]]$default
          if (!is.null(value)) {
            url <- gsub(paste0('{', name, '}'), value, url, fixed = TRUE)
          }
        }
        url
      },
      character(1)
    )
  }
  urls <- unique(urls)
  if (!length(urls)) {
    urls <- ''
  }
  if (nzchar(origin)) {
    if (!requireNamespace('httr2', quietly = TRUE)) {
      stop('Install httr2 to resolve schema origins')
    }
    urls <- vapply(
      urls,
      function(url) {
        httr2::url_build(httr2::url_parse(url, base_url = origin))
      },
      character(1)
    )
  }
  valid <- grepl('^https?://[^/]+', urls) & !grepl('[{}]', urls)
  if (length(urls) == 1L && valid[[1L]]) urls[[1L]] else ''
}

configure_apis <- function(
  root,
  schemas = NULL,
  origins = NULL,
  choices = NULL,
  review = NULL,
  mode = c('plan', 'apply')
) {
  mode <- match.arg(mode)
  root <- normalizePath(root, winslash = '/', mustWork = TRUE)
  if (is.null(schemas)) {
    schemas <- list.files(root, '\\.json$', full.names = TRUE)
  }
  if (!length(schemas)) {
    stop('No JSON schemas found')
  }
  paths <- normalizePath(schemas, winslash = '/', mustWork = TRUE)
  if (any(!startsWith(paths, paste0(root, '/')))) {
    stop('Schemas must be inside the project root')
  }
  relative <- substring(paths, nchar(root) + 2L)
  if (anyDuplicated(relative)) {
    stop('Duplicate schema path')
  }
  if (
    !is.null(origins) &&
      (is.null(names(origins)) ||
        anyDuplicated(names(origins)) ||
        any(!names(origins) %in% relative))
  ) {
    stop('origins must be named by relative schema path')
  }
  catalog_path <- project_path(root, 'specmill-apis.yml')
  prior_hash <- if (file.exists(catalog_path)) {
    output_hash(catalog_path)
  } else {
    NULL
  }
  previous <- if (file.exists(catalog_path)) {
    data <- read_config_yaml(catalog_path)
    config_fields(data, c('catalog_version', 'apis'), 'API catalogue')
    if (!identical(data$catalog_version, 1L)) {
      stop('Unsupported API catalogue version')
    }
    config_data(data$apis)
  } else {
    list()
  }
  rows <- lapply(seq_along(paths), function(i) {
    document <- jsonlite::read_json(paths[[i]])
    version <- document$openapi %or% document$swagger %or% ''
    if (!grepl('^(3\\.[01]\\.|2\\.0$)', version) || is.null(document$paths)) {
      stop('Not a supported API schema: ', relative[[i]])
    }
    hash <- schema_identity(document)
    matches <- Filter(
      function(record) identical(record$schema, relative[[i]]),
      previous
    )
    if (!length(matches)) {
      matches <- Filter(function(record) identical(record$hash, hash), previous)
    }
    prior <- if (length(matches) == 1L) matches[[1L]] else list()
    title <- document$info$title %or% 'Unnamed API'
    suggested <- configuration_words(sub(
      ' (API|Module)$',
      '',
      sub('^.* - ', '', title)
    ))
    if (
      !nzchar(suggested) ||
        grepl('^[0-9]|^(con|prn|aux|nul|com[0-9]|lpt[0-9])$', suggested)
    ) {
      suggested <- paste0('api_', suggested)
    }
    origin <- if (relative[[i]] %in% names(origins)) {
      origins[[relative[[i]]]]
    } else {
      prior$origin %or% ''
    }
    base_url <- prior$base_url %or% schema_server(document, origin)
    data.frame(
      schema = relative[[i]],
      title = title,
      api = prior$api %or% suggested,
      base_url = base_url,
      include = prior$include %or% TRUE,
      origin = origin,
      hash = hash,
      saved = identical(prior$hash, hash),
      stringsAsFactors = FALSE
    )
  })
  table <- do.call(rbind, rows)
  # Equal schema content is a duplicate even when formatting or filenames differ.
  duplicate <- duplicated(table$hash)
  table$include[duplicate & !table$saved] <- FALSE
  unique_rows <- !duplicated(table$hash)
  conflict_names <- table$api[unique_rows][duplicated(table$api[unique_rows])]
  conflicts <- table$api %in% conflict_names
  table$api[conflicts & !table$saved] <- paste0(
    table$api[conflicts & !table$saved],
    '_',
    substr(table$hash[conflicts & !table$saved], 1L, 8L)
  )
  table$status <- ifelse(
    duplicate,
    'Duplicate schema content',
    ifelse(
      !nzchar(table$base_url),
      'Needs base URL or download origin',
      'Ready for review'
    )
  )
  if (is.null(review)) {
    review <- interactive() && any(!table$saved)
  }
  table$saved <- NULL
  before <- table
  if (!is.null(choices)) {
    if (
      !is.data.frame(choices) ||
        !'schema' %in% names(choices) ||
        anyDuplicated(choices$schema) ||
        any(!choices$schema %in% table$schema) ||
        any(!names(choices) %in% c('schema', 'api', 'base_url', 'include'))
    ) {
      stop(
        'choices must be a data frame with schema and optional api, base_url, include columns'
      )
    }
    for (field in setdiff(names(choices), 'schema')) {
      table[match(choices$schema, table$schema), field] <- choices[[field]]
    }
  }
  if (review) {
    if (!interactive()) {
      stop(
        'Interactive review requires an R session; use review = FALSE to preview'
      )
    }
    message(
      'Review API names, base URLs and include flags together. Close the editor to continue.'
    )
    table <- utils::edit(table)
  }
  if (
    !is.data.frame(table) ||
      !identical(names(table), names(before)) ||
      !identical(
        table[c('schema', 'title', 'origin', 'hash', 'status')],
        before[c('schema', 'title', 'origin', 'hash', 'status')]
      )
  ) {
    stop('Only api, base_url and include may be edited')
  }
  if (!is.logical(table$include) || anyNA(table$include)) {
    stop('include must contain TRUE or FALSE')
  }
  selected <- table[table$include, , drop = FALSE]
  if (
    !is.character(table$api) ||
      anyNA(table$api) ||
      any(!grepl('^[a-z][a-z0-9_]*$', table$api)) ||
      anyDuplicated(selected$api)
  ) {
    stop(
      'Included APIs need distinct lowercase names using letters, digits and underscores'
    )
  }
  if (!is.character(table$base_url) || anyNA(table$base_url)) {
    stop('base_url must contain strings')
  }
  if (mode == 'apply') {
    if (!nrow(selected)) {
      stop('Select at least one API')
    }
    if (
      any(!grepl('^https?://[^/]+', selected$base_url)) ||
        any(grepl('[{}]', selected$base_url))
    ) {
      stop('Supply an absolute base URL for every included API before saving')
    }
    records <- lapply(seq_len(nrow(table)), function(i) {
      as.list(table[
        i,
        c('schema', 'hash', 'api', 'base_url', 'include', 'origin')
      ])
    })
    if (file.exists(catalog_path)) {
      # The catalogue is explicitly maintained here; abort if another writer changed it during review.
      current <- config_data(read_config_yaml(catalog_path)$apis)
      if (!identical(current, previous)) {
        stop('API catalogue changed during review; retry')
      }
    }
    apply_files(
      root,
      list(
        'specmill-apis.yml' = sub(
          '\n$',
          '',
          yaml::as.yaml(list(catalog_version = 1L, apis = records))
        )
      ),
      mode = 'apply',
      owned = function(path) identical(output_hash(path), prior_hash)
    )
  }
  table
}
