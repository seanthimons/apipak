read_schema_document <- function(path) {
  if (!tolower(tools::file_ext(path)) %in% c('yaml', 'yml')) {
    return(jsonlite::fromJSON(path, simplifyVector = FALSE))
  }
  text <- paste(
    readLines(path, encoding = 'UTF-8', warn = FALSE),
    collapse = '\n'
  )
  # yaml12 currently drops identical duplicate keys. Validate them with yaml,
  # disabling its YAML 1.1 scalar coercions and sequence simplification.
  scalar_tags <- c(
    'str',
    'null',
    'bool',
    'bool#yes',
    'bool#no',
    'bool#na',
    'int',
    'int#hex',
    'int#oct',
    'int#base60',
    'int#na',
    'float',
    'float#fix',
    'float#exp',
    'float#base60',
    'float#inf',
    'float#neginf',
    'float#nan',
    'float#na',
    'str#na',
    'timestamp',
    'timestamp#ymd',
    'timestamp#iso8601',
    'timestamp#spaced'
  )
  tag_error <- NULL
  scalar <- function(x) {
    if (!is.character(x) || length(x) != 1L) {
      tag_error <<- 'YAML scalar tag applied to a collection'
    }
    x
  }
  sequence <- function(x) {
    if (!is.list(x) || !is.null(names(x))) {
      tag_error <<- 'YAML sequence tag applied to a non-sequence'
    }
    x
  }
  mapping <- function(x) {
    if (!is.list(x) || is.null(names(x))) {
      tag_error <<- 'YAML mapping tag applied to a non-mapping'
    }
    x
  }
  withCallingHandlers(
    yaml::yaml.load(
      text,
      handlers = c(
        stats::setNames(rep(list(scalar), length(scalar_tags)), scalar_tags),
        list(seq = sequence, map = mapping)
      ),
      eval.expr = FALSE,
      error.label = path
    ),
    warning = function(w) stop(conditionMessage(w), call. = FALSE)
  )
  if (!is.null(tag_error)) {
    stop(tag_error, ': ', path, call. = FALSE)
  }
  documents <- yaml12::parse_yaml(text, multi = TRUE, simplify = FALSE)
  if (length(documents) != 1L) {
    stop('Expected exactly one YAML schema document: ', path, call. = FALSE)
  }
  normalize <- function(x) {
    if (!is.null(attr(x, 'yaml_tag'))) {
      stop('Unsupported YAML tag in ', path, call. = FALSE)
    }
    # yaml12 casts -2147483648 to R's reserved NA_integer_ sentinel. YAML
    # null is NULL, so this integer sentinel unambiguously denotes that bound.
    if (identical(x, NA_integer_)) {
      return(-2147483648)
    }
    if (is.numeric(x) && any(!is.finite(x))) {
      stop('Non-finite YAML number in ', path, call. = FALSE)
    }
    if (!is.list(x)) {
      return(x)
    }
    keys <- attr(x, 'yaml_keys')
    if (!is.null(keys)) {
      names(x) <- vapply(
        keys,
        function(key) {
          key <- normalize(key)
          if (
            is.character(key) && length(key) == 1L && is.null(attributes(key))
          ) {
            return(key)
          }
          if (
            is.numeric(key) &&
              length(key) == 1L &&
              is.finite(key) &&
              key == trunc(key) &&
              abs(key) <= 2^53 - 1 &&
              is.null(attributes(key))
          ) {
            return(format(key, scientific = FALSE, trim = TRUE, digits = 22))
          }
          stop('Unsupported YAML mapping key in ', path, call. = FALSE)
        },
        character(1)
      )
      attr(x, 'yaml_keys') <- NULL
    }
    if (anyDuplicated(names(x))) {
      stop('Duplicate YAML mapping key in ', path, call. = FALSE)
    }
    if ('<<' %in% names(x)) {
      stop('YAML merge keys are unsupported in ', path, call. = FALSE)
    }
    lapply(x, normalize)
  }
  normalize(documents[[1L]])
}
