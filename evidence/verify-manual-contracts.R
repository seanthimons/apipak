verify_manual_contracts <- function(root) {
  withr::local_envvar(c(COMPTOXR_CRAN_SAFE_TESTS = 'true', NOT_CRAN = 'false', ctx_api_key = NA, GITHUB_OUTPUT = NA))
  devtools::test(root, filter = '^(chemi_classyfire|chemi_toxprint|ct_related|ct_similar|pubchem_properties|pubchem_search|pubchem_synonyms|remove_experimental)$', stop_on_failure = TRUE)
}
if (sys.nframe() == 0L) verify_manual_contracts(commandArgs(trailingOnly = TRUE)[[1L]])
