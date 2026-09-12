# source('testing_specs.R'); source('dev/download_testing_specs.R')
# download_testing_specs(specs, 'C:/Users/sxthi/Documents/specmill-testing')
download_testing_specs <- function(specs, root) {
  stopifnot(
    all(c('tier', 'stresses', 'url') %in% names(specs)),
    dir.exists(root)
  )
  destination <- file.path(root, 'additional-schemas')
  dir.create(destination, recursive = TRUE, showWarnings = FALSE)
  queue <- as.data.frame(specs[c('tier', 'stresses', 'url')])
  rows <- list()
  refs <- function(x) {
    if (!is.list(x)) {
      return(character())
    }
    ref <- if (!is.null(names(x))) x[['$ref']]
    if (!is.character(ref) || length(ref) != 1L) {
      ref <- character()
    }
    children <- if (is.null(names(x))) {
      x
    } else {
      x[!names(x) %in% c('example', 'examples', 'default', 'enum', 'const')]
    }
    c(ref, unlist(lapply(children, refs), use.names = FALSE))
  }
  i <- 1L
  while (i <= nrow(queue)) {
    url <- queue$url[[i]]
    # Mirror upstream paths so relative reference targets can be placed beside them.
    stopifnot(
      startsWith(url, 'https://raw.githubusercontent.com/'),
      !grepl('/\\.\\./', url)
    )
    relative <- sub('https://raw.githubusercontent.com/', '', url, fixed = TRUE)
    path <- file.path(destination, relative)
    dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
    status <- 'present'
    error <- ''
    temporary <- tempfile('schema-download-', tmpdir = dirname(path))
    if (!file.exists(path)) {
      status <- tryCatch(
        {
          request <- httr2::req_timeout(httr2::request(url), 90)
          httr2::req_perform(request, path = temporary)
          if (!file.info(temporary)$size) {
            stop('Empty download')
          }
          stopifnot(file.rename(temporary, path))
          'downloaded'
        },
        error = function(e) {
          error <<- conditionMessage(e)
          'failed'
        }
      )
    }
    if (file.exists(temporary)) {
      unlink(temporary)
    }
    version <- ''
    parse_error <- ''
    parse_warning <- character()
    if (file.exists(path)) {
      document <- tryCatch(
        withCallingHandlers(
          {
            if (grepl('\\.json$', path)) {
              jsonlite::read_json(path)
            } else {
              yaml::yaml.load(
                paste(
                  readLines(path, encoding = 'UTF-8', warn = FALSE),
                  collapse = '\n'
                ),
                eval.expr = FALSE
              )
            }
          },
          warning = function(w) {
            parse_warning <<- unique(c(parse_warning, conditionMessage(w)))
            invokeRestart('muffleWarning')
          }
        ),
        error = function(e) {
          parse_error <<- conditionMessage(e)
          NULL
        }
      )
      if (is.list(document) && !is.null(names(document))) {
        version <- if (!is.null(document$openapi)) {
          document$openapi
        } else if (!is.null(document$swagger)) {
          document$swagger
        } else {
          ''
        }
      }
      if (queue$tier[[i]] != 'json-schema' && is.list(document)) {
        targets <- unique(sub('#.*$', '', refs(document)))
        targets <- targets[
          nzchar(targets) & !grepl('^[a-zA-Z][a-zA-Z0-9+.-]*:', targets)
        ]
        resolved <- vapply(
          targets,
          function(target) {
            httr2::url_build(httr2::url_parse(target, base_url = url))
          },
          character(1)
        )
        repository <- paste0(
          'https://raw.githubusercontent.com/',
          paste(
            head(strsplit(relative, '/', fixed = TRUE)[[1L]], 3L),
            collapse = '/'
          ),
          '/'
        )
        resolved <- setdiff(
          resolved[startsWith(resolved, repository)],
          queue$url
        )
        if (length(resolved)) {
          queue <- rbind(
            queue,
            data.frame(
              tier = 'reference',
              stresses = paste('Relative reference from', relative),
              url = resolved
            )
          )
        }
      }
    }
    message(i, '/', nrow(queue), ': ', status, ' ', relative)
    rows[[i]] <- data.frame(
      tier = queue$tier[[i]],
      stresses = queue$stresses[[i]],
      url = url,
      file = relative,
      status = status,
      bytes = if (file.exists(path)) file.info(path)$size else NA_real_,
      sha256 = if (file.exists(path)) {
        digest::digest(file = path, algo = 'sha256')
      } else {
        ''
      },
      version = version,
      error = error,
      parse_error = parse_error,
      parse_warning = paste(parse_warning, collapse = '; '),
      stringsAsFactors = FALSE
    )
    i <- i + 1L
  }
  manifest <- do.call(rbind, rows)
  write.csv(manifest, file.path(destination, 'manifest.csv'), row.names = FALSE)
  writeLines(
    c(
      '# Additional testing schemas',
      '',
      'Downloaded from the user-supplied testing_specs.R list. manifest.csv records',
      'source URLs, local paths, versions, hashes, failures, and parse errors.',
      'Files retain their upstream directory layout. No active API configuration',
      'or existing helper was changed. OpenAPI 3.2 and JSON Schema test arrays are',
      'retained as test inputs; they are not automatically registered as APIs.',
      'Same-repository relative $ref targets were downloaded transitively.',
      'Absolute remote references and JSON Schema test-suite remotes were not fetched.',
      'Failed URLs remain in the manifest for correction.'
    ),
    file.path(destination, 'PICKUP.md')
  )
  invisible(manifest)
}
