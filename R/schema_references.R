schema_reference_error <- function(ref, code, message) {
  structure(
    list(
      '$ref' = ref,
      'x-specmill-reference-error' = list(code = code, message = message)
    ),
    class = 'specmill_reference_error'
  )
}

schema_reference_pointer <- function(document, fragment, ref) {
  if (!fragment %in% c('', '#') && !startsWith(fragment, '#/')) {
    return(schema_reference_error(
      ref,
      'local_reference',
      paste('Unsupported local reference fragment:', ref)
    ))
  }
  if (fragment %in% c('', '#')) {
    return(document)
  }
  parts <- strsplit(sub('^#/', '', fragment), '/', fixed = TRUE)[[1L]]
  if (any(grepl('~([^01]|$)', parts))) {
    return(schema_reference_error(
      ref,
      'invalid_reference',
      paste('Invalid reference escape:', ref)
    ))
  }
  parts <- gsub('~0', '~', gsub('~1', '/', parts, fixed = TRUE), fixed = TRUE)
  value <- document
  for (part in parts) {
    if (!is.list(value)) {
      return(schema_reference_error(
        ref,
        'unresolved_reference',
        paste('Missing reference:', ref)
      ))
    }
    index <- if (is.null(names(value)) && grepl('^(0|[1-9][0-9]*)$', part)) {
      as.integer(part) + 1L
    } else {
      part
    }
    missing <- if (is.numeric(index)) {
      is.na(index) || index > length(value) || is.null(value[[index]])
    } else {
      is.null(value[[index]])
    }
    if (missing) {
      return(schema_reference_error(
        ref,
        'unresolved_reference',
        paste('Missing reference:', ref)
      ))
    }
    value <- value[[index]]
  }
  value
}

resolve_schema_references <- function(document, path) {
  root <- normalizePath(path, winslash = '/', mustWork = TRUE)
  dependencies <- stats::setNames(tools::md5sum(root), root)
  documents <- list()
  resolved <- list()
  load_document <- function(file) {
    file <- normalizePath(file, winslash = '/', mustWork = TRUE)
    if (!file %in% names(dependencies)) {
      dependencies[[file]] <<- tools::md5sum(file)
    }
    if (is.null(documents[[file]])) {
      documents[[file]] <<- read_schema_document(
        file,
        resolve_references = FALSE
      )
    }
    documents[[file]]
  }
  resolve <- function(
    node,
    current,
    file,
    inline_local = FALSE,
    stack = character(),
    allow_ref = TRUE
  ) {
    if (!is.list(node)) {
      return(node)
    }
    ref <- node[['$ref']]
    if (!allow_ref || is.null(ref) || !is.character(ref) || length(ref) != 1L) {
      if (is.null(names(node))) {
        return(lapply(
          node,
          resolve,
          current = current,
          file = file,
          inline_local = inline_local,
          stack = stack
        ))
      }
      result <- lapply(names(node), function(name) {
        value <- node[[name]]
        if (name %in% c('example', 'examples', 'default', 'enum', 'const')) {
          return(value)
        }
        resolve(value, current, file, inline_local, stack)
      })
      names(result) <- names(node)
      return(result)
    }
    if (is.na(ref)) {
      return(schema_reference_error(
        '',
        'invalid_reference',
        'Reference must be a string'
      ))
    }
    split <- regexpr('#', ref, fixed = TRUE)[[1L]]
    target_file <- if (split < 0L) ref else substr(ref, 1L, split - 1L)
    fragment <- if (split < 0L) '' else substr(ref, split, nchar(ref))
    external <- nzchar(target_file)
    if (external && grepl('^(?:[A-Za-z][A-Za-z0-9+.-]*:|//)', target_file)) {
      return(schema_reference_error(
        ref,
        'external_reference',
        paste('Remote reference is not fetched:', ref)
      ))
    }
    if (!external && !inline_local) {
      return(node)
    }
    if (external) {
      target_path <- normalizePath(
        file.path(dirname(file), utils::URLdecode(target_file)),
        winslash = '/',
        mustWork = FALSE
      )
      if (!file.exists(target_path)) {
        return(schema_reference_error(
          ref,
          'unresolved_reference',
          paste('Missing reference file:', ref)
        ))
      }
      target_document <- tryCatch(
        load_document(target_path),
        error = function(e) {
          schema_reference_error(
            ref,
            'invalid_reference',
            paste('Cannot read reference:', ref)
          )
        }
      )
      if (inherits(target_document, 'specmill_reference_error')) {
        return(target_document)
      }
    } else {
      target_path <- file
      target_document <- current
    }
    target <- schema_reference_pointer(target_document, fragment, ref)
    if (inherits(target, 'specmill_reference_error')) {
      return(target)
    }
    identity <- paste0(target_path, fragment %or% '#')
    if (length(stack) >= 100L) {
      return(schema_reference_error(
        ref,
        'reference_depth',
        'Reference nesting exceeds 100 levels'
      ))
    }
    if (identity %in% stack) {
      return(schema_reference_error(
        ref,
        'recursive_reference',
        paste('Recursive reference:', ref)
      ))
    }
    if (!is.null(resolved[[identity]])) {
      target <- resolved[[identity]]
    } else {
      target <- resolve(
        target,
        target_document,
        target_path,
        TRUE,
        c(stack, identity)
      )
      resolved[[identity]] <<- target
    }
    if (inherits(target, 'specmill_reference_error')) {
      return(target)
    }
    siblings <- node[setdiff(names(node), '$ref')]
    if (length(setdiff(names(siblings), c('summary', 'description')))) {
      return(schema_reference_error(
        ref,
        'reference_siblings',
        paste(
          'Bundled reference assertion siblings require an explicit allOf:',
          ref
        )
      ))
    }
    siblings <- lapply(
      siblings,
      resolve,
      current = current,
      file = file,
      inline_local = inline_local,
      stack = stack
    )
    if (length(siblings)) {
      target <- utils::modifyList(target, siblings)
    }
    target
  }
  resolved <- resolve(document, document, root)
  if (length(dependencies) > 1L) {
    attr(resolved, 'specmill_reference_dependencies') <- dependencies
  }
  resolved
}
