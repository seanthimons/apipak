parameter_transport_acceptance <- function() {
  source(
    if (file.exists('tests/native-transport.R')) {
      'tests/native-transport.R'
    } else {
      'native-transport.R'
    },
    local = TRUE
  )
  native_transport_acceptance(function(runtime, root) {
    file <- file.path(root, 'parameters.json')
    scalar <- list(type = 'string')
    array <- list(type = 'array', items = scalar)
    object <- list(
      type = 'object',
      properties = list(R = list(type = 'integer'), G = list(type = 'integer'))
    )
    count <- 0L
    requests <- 0L
    check <- function(
      schema,
      location,
      style = NULL,
      explode = NULL,
      value = NULL,
      expected,
      version = '3.0.3',
      collection = NULL,
      omit = FALSE,
      invalid = FALSE
    ) {
      p <- list(
        name = if (location == 'header') 'X-Test' else 'p',
        'in' = location,
        required = location == 'path',
        schema = schema
      )
      if (!is.null(style)) {
        p$style <- style
      }
      if (!is.null(explode)) {
        p$explode <- explode
      }
      if (version == '2.0') {
        p$schema <- NULL
        p <- c(p, schema)
        if (!is.null(collection)) p$collectionFormat <- collection
      }
      path <- if (location == 'path') '/wire{p}' else '/wire'
      document <- list(
        info = list(title = 'Parameters', version = '1'),
        paths = setNames(
          list(list(
            get = list(
              operationId = 'wire',
              parameters = list(p),
              responses = list('200' = list(description = 'OK'))
            )
          )),
          path
        )
      )
      document[[if (version == '2.0') 'swagger' else 'openapi']] <- version
      jsonlite::write_json(document, file, auto_unbox = TRUE, null = 'null')
      parsed <- specmill::read_operations(file)
      stopifnot(!length(parsed$diagnostics), length(parsed$operations) == 1L)
      op <- parsed$operations[[1L]]
      # Fixtures use the same public shape accepted by generated wrappers.
      fixture <- specmill::operation_fixtures(parsed$operations)[[1L]]
      eval(
        parse(
          text = specmill::render_operation(op, list(helper = 'api_request'))
        ),
        runtime
      )
      invoke <- function() if (omit) runtime$wire() else runtime$wire(value)
      if (invalid) {
        error <- tryCatch(invoke(), error = identity)
        stopifnot(
          inherits(error, 'error'),
          grepl(expected, conditionMessage(error))
        )
        result <- runtime$api_request('GET', '/probe', list(), list(), NULL)
      } else {
        result <- invoke()
        actual <- switch(
          location,
          query = result$query,
          path = result$path,
          header = result$parameter_header,
          cookie = result$cookie
        )
        if (!identical(actual, expected)) {
          print(list(
            location = location,
            style = style,
            actual = actual,
            expected = expected,
            response = result
          ))
          stop('Parameter wire contract differs')
        }
      }
      stopifnot(result$request_number == requests + 1L)
      requests <<- result$request_number
      result <- do.call(runtime$wire, fixture)
      stopifnot(result$request_number == requests + 1L)
      requests <<- result$request_number
      count <<- count + 1L
      invisible(op)
    }
    # RFC 6570 expansions; tokens are encoded before structural delimiters.
    for (explode in c(FALSE, TRUE)) {
      check(
        array,
        'path',
        'simple',
        explode,
        c('blue', 'black'),
        '/wireblue,black'
      )
      check(
        object,
        'path',
        'simple',
        explode,
        list(R = 1L, G = 2L),
        if (explode) '/wireR=1,G=2' else '/wireR,1,G,2'
      )
      check(
        array,
        'path',
        'label',
        explode,
        c('blue', 'black'),
        if (explode) '/wire.blue.black' else '/wire.blue,black'
      )
      check(
        object,
        'path',
        'label',
        explode,
        list(R = 1L, G = 2L),
        if (explode) '/wire.R=1.G=2' else '/wire.R,1,G,2'
      )
      check(
        array,
        'path',
        'matrix',
        explode,
        c('blue', 'black'),
        if (explode) '/wire;p=blue;p=black' else '/wire;p=blue,black'
      )
      check(
        object,
        'path',
        'matrix',
        explode,
        list(R = 1L, G = 2L),
        if (explode) '/wire;R=1;G=2' else '/wire;p=R,1,G,2'
      )
      check(
        object,
        'query',
        'form',
        explode,
        list(R = 1L, G = 2L),
        if (explode) '?R=1&G=2' else '?p=R,1,G,2'
      )
      check(
        array,
        'query',
        'form',
        explode,
        c('a,b', 'c/d'),
        if (explode) '?p=a%2Cb&p=c%2Fd' else '?p=a%2Cb,c%2Fd'
      )
      check(array, 'header', 'simple', explode, c('a', 'b'), 'a,b')
      check(
        object,
        'header',
        'simple',
        explode,
        list(R = 1L, G = 2L),
        if (explode) 'R=1,G=2' else 'R,1,G,2'
      )
      check(
        array,
        'cookie',
        'form',
        explode,
        c('a;b', 'c=d'),
        if (explode) 'p=a%3Bb; p=c%3Dd' else 'p=a%3Bb,c%3Dd'
      )
      check(
        object,
        'cookie',
        'form',
        explode,
        list(R = 1L, G = 2L),
        if (explode) 'R=1; G=2' else 'p=R,1,G,2'
      )
    }
    check(scalar, 'path', 'label', value = 'a/b', expected = '/wire.a%2Fb')
    check(scalar, 'path', 'matrix', value = '', expected = '/wire;p')
    check(array, 'path', 'label', TRUE, c('a.b', 'c'), '/wire.a%2Eb.c')
    check(array, 'path', 'simple', FALSE, c('a,b', '%2F'), '/wirea%2Cb,%252F')
    check(
      array,
      'query',
      'spaceDelimited',
      FALSE,
      c('a', 'c'),
      '?p=a%20c'
    )
    check(array, 'query', 'pipeDelimited', FALSE, c('a|b', 'c'), '?p=a%7Cb|c')
    check(
      array,
      'query',
      'spaceDelimited',
      FALSE,
      c('a b', 'c'),
      'whitespace delimiter',
      invalid = TRUE
    )
    check(array, 'query', 'spaceDelimited', TRUE, c('a b', 'c'), '?p=a%20b&p=c')
    check(array, 'query', 'pipeDelimited', TRUE, c('a|b', 'c'), '?p=a%7Cb&p=c')
    check(
      object,
      'query',
      'deepObject',
      TRUE,
      list(R = 1L, G = 2L),
      '?p[R]=1&p[G]=2'
    )
    check(
      list(type = 'object'),
      'query',
      'deepObject',
      TRUE,
      list('a/b' = 'x&y', utf8 = intToUtf8(0xE9)),
      '?p[a%2Fb]=x%26y&p[utf8]=%C3%A9'
    )
    check(
      list(type = 'array', items = list(type = 'boolean')),
      'query',
      value = c(FALSE, TRUE),
      expected = '?p=false&p=true'
    )
    check(
      list(type = 'array', items = list(type = 'number')),
      'query',
      value = c(0, 1.5),
      expected = '?p=0&p=1.5'
    )
    check(scalar, 'cookie', value = 'x y', expected = 'p=x%20y')
    check(scalar, 'cookie', value = '', expected = 'p=')
    check(scalar, 'cookie', omit = TRUE, expected = NULL)
    check(
      list(
        type = 'array',
        items = list(type = 'integer'),
        default = list(0L, 2L)
      ),
      'query',
      omit = TRUE,
      expected = '?p=0&p=2'
    )
    check(object, 'query', omit = TRUE, expected = '')
    check(
      list(type = 'array', items = scalar, default = list('a', 'b')),
      'query',
      omit = TRUE,
      expected = '?p=a&p=b'
    )
    check(scalar, 'query', value = '', expected = '?p=')
    check(
      array,
      'query',
      value = character(),
      invalid = TRUE,
      expected = 'Empty parameter containers'
    )
    check(
      object,
      'query',
      value = list(R = list(1L)),
      invalid = TRUE,
      expected = 'scalars'
    )
    check(
      array,
      'header',
      value = c('a,b', 'c'),
      invalid = TRUE,
      expected = 'delimiters'
    )
    check(
      array,
      'header',
      value = c('a\r\nb', 'c'),
      invalid = TRUE,
      expected = 'Newlines'
    )
    check(
      list(type = 'array', items = list(type = 'integer')),
      'query',
      value = c(1, NA),
      invalid = TRUE,
      expected = 'scalars'
    )
    for (format in c('csv', 'ssv', 'tsv', 'pipes', 'multi')) {
      expected <- switch(
        format,
        csv = '?p=a,b',
        ssv = '?p=a%20b',
        tsv = '?p=a%09b',
        pipes = '?p=a|b',
        multi = '?p=a&p=b'
      )
      check(
        array,
        'query',
        value = c('a', 'b'),
        expected = expected,
        version = '2.0',
        collection = format
      )
    }
    check(
      array,
      'header',
      value = c('a', 'b'),
      expected = 'a|b',
      version = '2.0',
      collection = 'pipes'
    )
    check(
      array,
      'path',
      value = c('a', 'b'),
      expected = '/wirea,b',
      version = '2.0'
    )
    cat(
      'Parameter serialization:',
      count,
      'generated localhost contracts passed.\n'
    )
  })
}
if (sys.nframe() == 0L) {
  parameter_transport_acceptance()
}
