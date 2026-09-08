comptox_interface_probe <- function(
  baseline = 'evidence/baseline',
  support = 'evidence/schema-support.rds',
  output = 'evidence/interface-probe.rds'
) {
  frozen <- readRDS(file.path(baseline, 'public-contracts.rds'))
  schemas <- readRDS(support)
  operations <- do.call(c, unname(lapply(schemas, `[[`, 'operations')))
  definitions <- list()
  for (file in names(frozen)) {
    for (definition in frozen[[file]]$definitions) {
      definitions[[definition$name]] <- c(
        definition,
        list(file = file, ownership = frozen[[file]]$ownership)
      )
    }
  }
  constant <- function(x) {
    if (is.atomic(x) || is.null(x)) {
      return(x)
    }
    if (
      is.call(x) &&
        is.symbol(x[[1L]]) &&
        as.character(x[[1L]]) %in% c('c', 'list')
    ) {
      return(do.call(
        get(as.character(x[[1L]]), baseenv()),
        lapply(as.list(x)[-1L], constant)
      ))
    }
    stop('Nonliteral default: ', paste(deparse(x), collapse = ' '))
  }
  results <- list()
  for (op in operations) {
    if (!op$service %in% c('ct', 'epi')) {
      next
    }
    definition <- definitions[[op$name]]
    if (is.null(definition)) {
      results[[op$id]] <- list(
        status = 'missing baseline definition',
        name = op$name
      )
      next
    }
    results[[op$id]] <- tryCatch(
      {
        expr <- parse(text = definition$code)[[1L]]
        formals <- getFromNamespace('tg_formal_records', 'apipak')(expr)
        inputs <- lapply(formals, function(formal) {
          input <- list(required = formal$required)
          if (!formal$required) {
            value <- constant(formal$default)
            input['default'] <- list(
              if (length(value) > 1L) as.list(value) else value
            )
            input$type <- if (is.character(value)) {
              'character'
            } else if (is.logical(value)) {
              'logical'
            } else if (is.integer(value)) {
              'integer'
            } else if (is.numeric(value)) {
              'numeric'
            } else {
              'object'
            }
          }
          input
        })
        if (!length(inputs)) {
          inputs <- stats::setNames(list(), character())
        }
        calls <- list()
        aliases <- list()
        body_assignments <- list()
        visit <- function(x) {
          if (missing(x) || !is.call(x)) {
            return(invisible(NULL))
          }
          if (is.symbol(x[[1L]])) {
            head <- as.character(x[[1L]])
            if (head %in% c('generic_request', 'generic_chemi_request')) {
              calls[[length(calls) + 1L]] <<- x
            }
            if (head == '<-' && is.symbol(x[[2L]])) {
              aliases[[as.character(x[[2L]])]] <<- x[[3L]]
            }
            if (
              head == '<-' &&
                is.call(x[[2L]]) &&
                identical(x[[2L]][[1L]], as.name('$')) &&
                identical(x[[2L]][[2L]], as.name('request_body'))
            ) {
              body_assignments[[as.character(x[[2L]][[3L]])]] <<- x[[3L]]
            }
          }
          for (child in as.list(x)[-1L]) {
            visit(child)
          }
        }
        visit(expr[[3L]])
        if (length(calls) != 1L) {
          stop('Expected one helper call; found ', length(calls))
        }
        reference <- function(x) {
          if (is.symbol(x)) {
            return(as.character(x))
          }
          if (
            is.call(x) &&
              is.symbol(x[[1L]]) &&
              as.character(x[[1L]]) %in% c('$', '[[')
          ) {
            key <- if (is.symbol(x[[3L]])) {
              as.character(x[[3L]])
            } else {
              constant(x[[3L]])
            }
            return(c(reference(x[[2L]]), key))
          }
          NULL
        }
        binding <- function(x, seen = character()) {
          if (
            identical(x, as.name('request_body')) && length(body_assignments)
          ) {
            return(list(compact_object = lapply(body_assignments, binding)))
          }
          if (is.atomic(x) || is.null(x)) {
            return(list(value = x))
          }
          path <- reference(x)
          if (length(path) && path[[1L]] == 'req_data') {
            return(list(from = as.list(c('hook_state', path[-1L]))))
          }
          if (length(path) && path[[1L]] %in% names(inputs)) {
            return(list(from = as.list(c('params', path))))
          }
          if (
            is.symbol(x) &&
              as.character(x) %in% names(aliases) &&
              !as.character(x) %in% seen
          ) {
            return(binding(
              aliases[[as.character(x)]],
              c(seen, as.character(x))
            ))
          }
          if (
            is.call(x) &&
              is.symbol(x[[1L]]) &&
              as.character(x[[1L]]) %in% c('c', 'list')
          ) {
            args <- as.list(x)[-1L]
            if (
              length(args) &&
                (is.null(names(args)) || any(!nzchar(names(args))))
            ) {
              stop('Unnamed grouped request arguments')
            }
            return(stats::setNames(
              list(stats::setNames(
                lapply(args, binding),
                if (is.null(names(args))) character() else names(args)
              )),
              if (as.character(x[[1L]]) == 'c') 'vector' else 'object'
            ))
          }
          code <- gsub('[[:space:]]', '', paste(deparse(x), collapse = ''))
          for (default in c('100', '1000')) {
            if (
              code ==
                paste0('as.numeric(Sys.getenv("batch_limit","', default, '"))')
            ) {
              return(list(callback = paste0('batch_limit_', default)))
            }
          }
          stop(
            'Unmapped request expression: ',
            paste(deparse(x), collapse = ' ')
          )
        }
        args <- as.list(calls[[1L]])[-1L]
        if (is.null(names(args)) || any(!nzchar(names(args)))) {
          stop('Unnamed helper argument')
        }
        settings <- list(
          inputs = inputs,
          helper = as.character(calls[[1L]][[1L]]),
          request = list(arguments = lapply(args, binding))
        )
        list(
          status = 'mapped request shape',
          name = op$name,
          file = definition$file,
          ownership = definition$ownership,
          settings = settings
        )
      },
      error = function(e) {
        list(
          status = conditionMessage(e),
          name = op$name,
          file = definition$file
        )
      }
    )
  }
  saveRDS(results, output)
  jsonlite::write_json(
    results,
    sub('\\.rds$', '.json', output),
    pretty = TRUE,
    auto_unbox = TRUE,
    null = 'null'
  )
  print(sort(
    table(vapply(results, `[[`, character(1), 'status')),
    decreasing = TRUE
  ))
  invisible(results)
}
if (sys.nframe() == 0L) {
  comptox_interface_probe()
}
