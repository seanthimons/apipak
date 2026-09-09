# Export and wrapper inventory.

client_definitions <- function(root) {
  files <- list.files(file.path(root, 'R'), '\\.R$', full.names = TRUE)
  definitions <- do.call(
    c,
    unname(lapply(files, tg_find_function_defs_in_file))
  ) %or%
    list()
  if (anyDuplicated(names(definitions))) {
    stop('Duplicate client runtime definitions')
  }
  definitions
}

tg_strip_namespace_quotes <- function(x) {
  x <- trimws(x)
  x <- sub('^"(.*)"$', "\\1", x)
  x <- sub("^'(.*)'$", "\\1", x)
  x
}

tg_parse_namespace_exports <- function(root = ".") {
  namespace_path <- tg_file_path(root, "NAMESPACE")
  lines <- tg_read_lines(namespace_path)
  export_lines <- grep("^\\s*export\\(", lines, value = TRUE)
  exports <- sub("^\\s*export\\((.*)\\)\\s*$", "\\1", export_lines, perl = TRUE)
  exports <- sort(unique(tg_strip_namespace_quotes(exports)))
  exports[!grepl("^%.*%$", exports)]
}

tg_call_name <- function(call) {
  if (!is.call(call)) {
    return(NA_character_)
  }

  head <- call[[1]]
  if (is.symbol(head)) {
    return(as.character(head))
  }

  if (
    is.call(head) &&
      is.symbol(head[[1]]) &&
      as.character(head[[1]]) %in% c("::", ":::")
  ) {
    return(as.character(head[[3]]))
  }

  NA_character_
}

tg_all_call_names <- function(expr) {
  tryCatch(
    all.names(expr, functions = TRUE, unique = FALSE),
    error = function(e) character(0)
  )
}

tg_find_function_defs_in_file <- function(file, documentation = FALSE) {
  exprs <- parse(file = file, keep.source = documentation)
  lines <- if (documentation) {
    readLines(file, warn = FALSE, encoding = 'UTF-8')
  } else {
    character()
  }
  defs <- list()

  for (i in seq_along(exprs)) {
    expr <- exprs[[i]]
    if (
      !is.call(expr) ||
        !is.symbol(expr[[1]]) ||
        !(as.character(expr[[1]]) %in% c("<-", "="))
    ) {
      next
    }

    lhs <- expr[[2]]
    rhs <- expr[[3]]
    if (
      !is.symbol(lhs) ||
        !is.call(rhs) ||
        !identical(rhs[[1]], as.name("function"))
    ) {
      next
    }

    function_name <- as.character(lhs)
    defs[[function_name]] <- list(
      function_name = function_name,
      file_path = file,
      expr = rhs,
      call_names = tg_all_call_names(rhs)
    )
    if (documentation) {
      end <- attr(exprs, 'srcref')[[i]][[1L]] - 1L
      while (end > 0L && !nzchar(trimws(lines[[end]]))) {
        end <- end - 1L
      }
      start <- end
      while (start > 0L && grepl("^\\s*#'", lines[[start]])) {
        start <- start - 1L
      }
      defs[[function_name]]$documentation <- if (end > start) {
        lines[seq.int(start + 1L, end)]
      } else {
        character()
      }
    }
  }

  defs
}

tg_find_exported_function_defs <- function(root = ".") {
  exports <- tg_parse_namespace_exports(root)
  files <- list.files(
    tg_file_path(root, "R"),
    pattern = "\\.R$",
    full.names = TRUE
  )
  defs <- list()

  for (file in files) {
    file_defs <- tg_find_function_defs_in_file(file)
    for (name in intersect(names(file_defs), exports)) {
      defs[[name]] <- file_defs[[name]]
    }
  }

  defs[sort(names(defs))]
}

tg_inventory_wrappers <- function(
  root = ".",
  helper_names = tg_config$helper_names
) {
  defs <- tg_find_exported_function_defs(root)
  records <- list()

  for (name in names(defs)) {
    helper_hits <- intersect(helper_names, defs[[name]]$call_names)
    if (length(helper_hits) == 0) {
      next
    }

    records[[name]] <- list(
      function_name = name,
      file_path = defs[[name]]$file_path,
      file = tg_rel_path(defs[[name]]$file_path, root),
      expr = defs[[name]]$expr,
      helper_names = helper_hits,
      call_names = defs[[name]]$call_names
    )
  }

  records[sort(names(records))]
}
