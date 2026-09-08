validate_hooks <- function(config, wrappers, hooks, callback = 'run_hook') {
  stopifnot(is.environment(hooks), is.list(wrappers))
  hook_config <- config
  errors <- character()
  hook_count <- 0L
  param_count <- 0L
  find_generated_wrapper <- function(fn_name) {
    fn <- wrappers[[fn_name]]
    if (is.null(fn)) return(list(found = FALSE))
    list(found = TRUE, file = fn_name, formals = names(formals(fn)), calls = collect_calls(body(fn)))
  }
collect_calls <- function(expression) {
  calls <- list()
  visit <- function(node) {
    if (!is.call(node)) {
      return(invisible(NULL))
    }
    calls[[length(calls) + 1L]] <<- node
    for (child in as.list(node)[-1L]) {
      visit(child)
    }
    invisible(NULL)
  }
  visit(expression)
  calls
}

call_name <- function(call) {
  if (!is.call(call) || !is.symbol(call[[1]])) {
    return(NA_character_)
  }
  as.character(call[[1]])
}

find_hook_call <- function(calls, fn_name, hook_type) {
  which(vapply(
    calls,
    function(call) {
      identical(call_name(call), callback) &&
        length(call) >= 3L &&
        identical(call[[2]], fn_name) &&
        identical(call[[3]], hook_type)
    },
    logical(1)
  ))
}

# Validate each function entry
for (fn_name in names(hook_config)) {
  fn_config <- hook_config[[fn_name]]
  wrapper <- find_generated_wrapper(fn_name)

  # Validate hook function references
  if (!is.null(fn_config$transform)) {
    errors <- c(
      errors,
      paste0("Function ", fn_name, " configures unsupported hook stage 'transform'")
    )
  }

  for (hook_type in c("pre_request", "post_response")) {
    if (!is.null(fn_config[[hook_type]])) {
      hook_names <- fn_config[[hook_type]]

      for (hook_fn in hook_names) {
        hook_count <- hook_count + 1

        # Check if hook function exists
        if (!exists(hook_fn, envir = hooks, mode = "function", inherits = FALSE)) {
          errors <- c(
            errors,
            paste0(
              "Function ",
              fn_name,
              " references missing hook: ",
              hook_fn,
              " (type: ",
              hook_type,
              ")"
            )
          )
        }
      }

      if (isTRUE(wrapper$found)) {
        if (length(find_hook_call(wrapper$calls, fn_name, hook_type)) == 0) {
          errors <- c(
            errors,
            paste0(
              "Function ",
              fn_name,
              " configures hook stage '",
              hook_type,
              "' but generated wrapper does not emit that stage (file: ",
              basename(wrapper$file),
              ")"
            )
          )
        }
      } else {
        invisible(NULL)
      }
    }
  }

  # Validate extra_params exist in generated stubs
  if (!is.null(fn_config$extra_params)) {
    if (isTRUE(wrapper$found)) {
      for (param_name in names(fn_config$extra_params)) {
        param_count <- param_count + 1

        if (!param_name %in% wrapper$formals) {
          errors <- c(
            errors,
            paste0(
              "Function ",
              fn_name,
              " declares extra_param '",
              param_name,
              "' but it's not in generated stub signature (file: ",
              basename(wrapper$file),
              ")"
            )
          )
        }
      }
    } else {
      # Stub doesn't exist yet - not an error (might be generated later)
      invisible(NULL)
    }
  }

  if (!is.null(fn_config$parameter_overrides) && isTRUE(wrapper$found)) {
    for (schema_name in names(fn_config$parameter_overrides)) {
      override <- fn_config$parameter_overrides[[schema_name]]
      public_name <- if (is.null(override$name)) make.names(schema_name) else override$name
      if (isTRUE(override$exclude)) {
        if (public_name %in% wrapper$formals) {
          errors <- c(
            errors,
            paste0(
              "Function ",
              fn_name,
              " excludes parameter '",
              public_name,
              "' but it remains in parsed formals"
            )
          )
        }
      } else if (!public_name %in% wrapper$formals) {
        errors <- c(
          errors,
          paste0(
            "Function ",
            fn_name,
            " maps parameter '",
            schema_name,
            "' to missing formal '",
            public_name,
            "'"
          )
        )
      }
    }
  }

  if (!is.null(fn_config$request_template)) {
    template <- fn_config$request_template
    helper <- template$helper
    if (!isTRUE(wrapper$found)) {
      next
    }
    helper_positions <- which(vapply(
      wrapper$calls,
      function(call) identical(call_name(call), helper),
      logical(1)
    ))
    pre_positions <- find_hook_call(wrapper$calls, fn_name, "pre_request")
    post_positions <- find_hook_call(wrapper$calls, fn_name, "post_response")
    if (length(helper_positions) == 0) {
      errors <- c(
        errors,
        paste0("Function ", fn_name, " does not call configured helper ", helper)
      )
    }
    if (
      length(pre_positions) == 0 ||
        length(post_positions) == 0 ||
        length(helper_positions) == 0 ||
        !(pre_positions[[1]] < helper_positions[[1]] &&
          helper_positions[[1]] < post_positions[[1]])
    ) {
      errors <- c(
        errors,
        paste0(
          "Function ",
          fn_name,
          " does not emit pre-request -> helper -> post-response order"
        )
      )
    }

    if (
      !is.list(template$args) ||
        length(template$args) == 0 ||
        is.null(names(template$args)) ||
        any(!nzchar(names(template$args)))
    ) {
      errors <- c(
        errors,
        paste0("Function ", fn_name, " has an invalid request-template argument mapping")
      )
    } else {
      helper_call <- if (length(helper_positions) > 0) {
        wrapper$calls[[helper_positions[[1]]]]
      } else {
        NULL
      }
      helper_args <- if (is.null(helper_call)) {
        list()
      } else {
        as.list(helper_call)[-1L]
      }
      for (argument_name in names(template$args)) {
        expression <- as.character(template$args[[argument_name]])
        parsed <- tryCatch(parse(text = expression), error = function(error) NULL)
        if (is.null(parsed)) {
          errors <- c(
            errors,
            paste0(
              "Function ",
              fn_name,
              " has invalid request expression for '",
              argument_name,
              "'"
            )
          )
        } else if (
          is.null(names(helper_args)) ||
            !argument_name %in% names(helper_args) ||
            !identical(helper_args[[argument_name]], parsed[[1]])
        ) {
          errors <- c(
            errors,
            paste0(
              "Function ",
              fn_name,
              " request argument '",
              argument_name,
              "' does not match configured expression ",
              expression
            )
          )
        }
      }
    }
  }
}


list(valid = !length(errors), errors = errors, functions = length(config), hooks = hook_count, parameters = param_count)
}
