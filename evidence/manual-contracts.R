manual_contracts <- function(root, apply = FALSE) {
  cases <- list(
    chemi_classyfire = list(helper = 'generic_request',
      inputs = quote(list(query = 'DTXSID7020182')),
      request = quote(list(query = 'DTXSID7020182', endpoint = 'amos/get_classification_for_dtxsid/', method = 'GET', batch_limit = 1, server = 'chemi_burl', auth = FALSE)),
      response = quote(tibble::tibble(query = 'DTXSID7020182', kingdom = 'Organic', superklass = 'Superclass', klass = 'Class', subklass = 'Subclass')),
      result = quote(tibble::tibble(dtxsid = 'DTXSID7020182', kingdom = 'Organic', superclass = 'Superclass', class = 'Class', subclass = 'Subclass'))),
    chemi_toxprint = list(helper = 'generic_chemi_request',
      inputs = quote(list(query = 'DTXSID7020182')),
      request = quote(list(query = 'DTXSID7020182', endpoint = 'toxprints/calculate', options = list(OR = 3L, PV1 = 0.05, TP = 3))),
      response = quote(tibble::tibble(bit = 'fixture', value = 1L)),
      result = quote(tibble::tibble(bit = 'fixture', value = 1L))),
    ct_related = list(helper = 'generic_request',
      inputs = quote(list(query = 'DTXSID7020182')),
      request = quote(list(query = NULL, endpoint = 'related-substances/search/by-dtxsid', method = 'GET', batch_limit = 0, server = 'https://comptox.epa.gov/dashboard-api/ccdapp2/', auth = FALSE, tidy = FALSE, id = 'DTXSID7020182')),
      response = quote(list(data = list(list(dtxsid = 'DTXSID7020182', relationship = 'self'), list(dtxsid = 'DTXSID0024842', relationship = 'parent')))),
      result = quote(tibble::tibble(query = 'DTXSID7020182', child = 'DTXSID0024842', relationship = 'parent'))),
    ct_similar = list(helper = 'generic_request',
      inputs = quote(list(query = 'DTXSID7020182')),
      request = quote(list(query = 'DTXSID7020182', endpoint = 'similar-compound/by-dtxsid/', method = 'GET', batch_limit = 1, server = 'https://comptox.epa.gov/dashboard-api/', 0.8)),
      response = quote(tibble::tibble(dtxsid = 'DTXSID0024842', similarity = 0.9)),
      result = quote(tibble::tibble(dtxsid = 'DTXSID0024842', similarity = 0.9))),
    pubchem_properties = list(helper = 'generic_pubchem_request',
      inputs = quote(list(cid = c(2244L, 6623L), properties = 'MolecularFormula', cache = FALSE)),
      request = quote(list(namespace = 'cid', operation = 'property/MolecularFormula', method = 'POST', body = list(cid = '2244,6623'), pluck_path = c('PropertyTable', 'Properties'), tidy = TRUE)),
      response = quote(tibble::tibble(CID = c(2244L, 6623L), MolecularFormula = c('C9H8O4', 'C8H10N4O2'))),
      result = quote(tibble::tibble(CID = c(2244L, 6623L), MolecularFormula = c('C9H8O4', 'C8H10N4O2')))),
    pubchem_search = list(helper = 'generic_pubchem_request',
      inputs = quote(list(query = 'aspirin', cache = FALSE)),
      request = quote(list(query = 'aspirin', namespace = 'name', operation = 'cids', pluck_path = c('IdentifierList', 'CID'), tidy = FALSE)),
      response = quote(list(2244L)), result = quote(tibble::tibble(cid = 2244L))),
    pubchem_synonyms = list(helper = 'generic_pubchem_request',
      inputs = quote(list(cid = 2244L, cache = FALSE)),
      request = quote(list(query = 2244L, namespace = 'cid', operation = 'synonyms', pluck_path = c('InformationList', 'Information'), tidy = FALSE)),
      response = quote(list(list(CID = 2244L, Synonym = c('aspirin', 'acetylsalicylic acid')))),
      result = quote(tibble::tibble(cid = c(2244L, 2244L), synonym = c('aspirin', 'acetylsalicylic acid'))))
  )
  baseline <- jsonlite::read_json('evidence/baseline/tracked-sha256.json')
  code <- function(expr) paste(deparse(expr, width.cutoff = 100L), collapse = '\n')
  for (name in names(cases)) {
    case <- cases[[name]]
    file <- paste0('tests/testthat/test-', name, '.R')
    path <- file.path(root, file)
    stopifnot(identical(digest::digest(file = path, algo = 'sha256'), baseline[[file]]))
    text <- paste(c(
      '# Intentional offline contract for a manual wrapper outside schema coverage.',
      paste0('test_that("', name, ' completes its manual helper contract", {'),
      paste0('  expected <- ', code(case$request)),
      paste0('  response <- ', code(case$response)),
      '  captured <- list()',
      paste0('  local_mocked_bindings(', case$helper, ' = function(...) {'),
      '    captured[[length(captured) + 1L]] <<- list(...)',
      '    response',
      '  }, .package = "ComptoxR")',
      paste0('  result <- do.call(ComptoxR::', name, ', ', code(case$inputs), ')'),
      '  expect_identical(captured, list(expected))',
      paste0('  expect_identical(result, ', code(case$result), ')'),
      '})'
    ), collapse = '\n')
    parse(text = text)
    if (apply) writeLines(text, path)
  }
  cat('Seven manual wrappers retain independent complete helper calls and typed successful-result contracts, outside schema totals.\n')
  invisible(names(cases))
}
if (sys.nframe() == 0L) {
  args <- commandArgs(trailingOnly = TRUE)
  manual_contracts(args[[1L]], '--apply' %in% args)
}
