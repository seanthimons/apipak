inspect_schema_gaps <- function() {
  frozen <- readRDS('evidence/baseline/public-contracts.rds')
  print(table(vapply(frozen, function(x) x$ownership$status, character(1))))
  print(head(lapply(frozen, `[[`, 'ownership'), 3L))
  if (file.exists('evidence/chemi-interface-probe.rds')) {
    mappings <- readRDS('evidence/chemi-interface-probe.rds')
    print(lapply(
      Filter(function(x) x$status != 'mapped request shape', mappings),
      function(x) x[c('name', 'status', 'file')]
    ))
  }
  records <- readRDS('evidence/schema-support.rds')
  for (record in records) {
    for (diagnostic in record$diagnostics) {
      if (!grepl('Invalid', diagnostic$reason)) {
        next
      }
      document <- jsonlite::read_json(diagnostic$source)
      parts <- strsplit(diagnostic$key, ' ', fixed = TRUE)[[1L]]
      cat(diagnostic$id, diagnostic$reason, '\n')
      str(document$paths[[parts[[2L]]]][[tolower(parts[[1L]])]], max.level = 4L)
    }
  }
}
if (sys.nframe() == 0L) {
  inspect_schema_gaps()
}
