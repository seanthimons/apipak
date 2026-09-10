coverage_report <- function(
  root,
  policy,
  callbacks = new.env(parent = emptyenv()),
  config = 'specmill.yml',
  mode = c('plan', 'apply')
) {
  mode <- match.arg(mode)
  root <- normalizePath(root, winslash = '/', mustWork = TRUE)
  if (is.character(policy)) {
    policy <- config_data(read_config_yaml(policy))
  }
  config_fields(policy, c('baseline', 'groups'), 'coverage policy')
  config_fields(policy$groups, names(policy$groups), 'coverage groups')
  baseline_path <- project_path(
    root,
    config_string(policy$baseline, 'coverage baseline')
  )
  baseline <- if (file.exists(baseline_path)) {
    jsonlite::read_json(baseline_path)
  } else {
    list()
  }
  inspection <- inspect_client(root, config, callbacks)
  selected <- character()
  values <- list()
  outputs <- list()
  badges <- list()
  delta <- function(current, previous) {
    if (
      is.null(previous) || is.na(previous) || abs(current - previous) < 1e-9
    ) {
      return('')
    }
    if (abs(current - round(current)) < 1e-9) {
      sprintf(' (%+d)', as.integer(round(current - previous)))
    } else {
      sprintf(' (%+.1f)', current - previous)
    }
  }
  for (name in names(policy$groups)) {
    group <- policy$groups[[name]]
    config_fields(group, c('services', 'label', 'badge'), 'coverage group')
    for (field in c('services', 'label', 'badge')) {
      config_string(group[[field]], field)
    }
    if (!grepl('^[a-z][a-z0-9_]*$', name)) {
      stop('Invalid coverage output prefix')
    }
    members <- grep(group$services, names(inspection$coverage), value = TRUE)
    if (!length(members) || length(intersect(selected, members))) {
      stop('Coverage groups are empty or overlap')
    }
    selected <- c(selected, members)
    coverage <- inspection$coverage[members]
    total <- sum(vapply(coverage, `[[`, integer(1), 'total'))
    implemented <- sum(vapply(coverage, `[[`, integer(1), 'implemented'))
    percent <- if (total) round(100 * implemented / total, 1) else 0
    color <- if (percent >= 80) {
      'brightgreen'
    } else if (percent >= 60) {
      'green'
    } else if (percent >= 40) {
      'yellow'
    } else if (percent >= 20) {
      'orange'
    } else {
      'red'
    }
    for (metric in c('coverage', 'endpoints', 'functions')) {
      key <- paste(name, metric, sep = '_')
      value <- switch(
        metric,
        coverage = percent,
        endpoints = total,
        functions = implemented
      )
      values[[key]] <- value
      outputs[[key]] <- if (metric == 'coverage') {
        sprintf('%.1f', value)
      } else {
        as.character(value)
      }
      outputs[[paste0(key, '_fmt')]] <- paste0(
        if (metric == 'coverage') {
          sprintf('%.1f%%', value)
        } else {
          as.character(value)
        },
        delta(value, baseline[[key]])
      )
    }
    outputs[[paste0(name, '_color')]] <- color
    path <- project_path(root, group$badge)
    badges[[path]] <- list(
      schemaVersion = 1,
      label = group$label,
      message = sprintf('%.1f%%', percent),
      color = color
    )
    cat(sprintf(
      '%s: %.1f%% (%d/%d)\n',
      group$label,
      percent,
      implemented,
      total
    ))
  }
  if (!setequal(selected, names(inspection$coverage))) {
    stop('Coverage policy omits configured services')
  }
  values$timestamp <- format(Sys.time(), '%Y-%m-%dT%H:%M:%SZ', tz = 'UTC')
  if (mode == 'apply') {
    for (path in names(badges)) {
      dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
      jsonlite::write_json(
        badges[[path]],
        path,
        auto_unbox = TRUE,
        pretty = TRUE
      )
    }
    jsonlite::write_json(
      values,
      baseline_path,
      auto_unbox = TRUE,
      pretty = TRUE
    )
    write_github_outputs(unlist(outputs, use.names = TRUE))
  }
  invisible(list(baseline = values, outputs = outputs, badges = badges))
}
