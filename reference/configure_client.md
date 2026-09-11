# Propose editable configuration from a schema

Discover every operation, group by its first tag, and propose project
and service YAML without generating endpoint functions.

## Usage

``` r
configure_client(root, schema, package = NULL,
    naming = c("operation_id", "tag_prefix"),
    group_by = c("tag", "none"), mode = c("plan", "apply"))
```

## Arguments

- root:

  Client directory. Planning does not create it.

- schema:

  Local OpenAPI 3.0/3.1 or Swagger 2.0 JSON file.

- package:

  R package name; read from DESCRIPTION when present. A supplied name
  must agree with existing metadata.

- naming:

  Preserve valid operationId names, or use tag-prefixed snake_case.
  Missing or invalid IDs get method/path names. Prefixing removes exact
  tag tokens and their simple plural, not synonyms.

- group_by:

  Group by first operation tag, or keep one default service. Missing
  tags use default. Untagged/default services keep per-function source
  files; other groups configure a shared R file and help family.

- mode:

  Preview by default. Apply creates absent files only; differing
  existing files or colliding tag filenames stop the entire write.

## Value

A list with named YAML/schema text in files, operation assignments in
operations, diagnostics, and changes. Each change contains file, action
(create, unchanged, conflict), before, and after. Schemas with security
declarations get an authentication map from scheme names to proposed
environment-variable names. It contains no tokens; names can be edited
before generation. API keys and HTTP bearer tokens are supported; OAuth
login and refresh are deferred.

## Details

The proposal includes a schema copy, specmill.yml, and apis/\*.yml. Each
service selects exact METHOD /path pairs through selection.include.
Multiple tags use the first tag with a diagnostic. Names and tag
filenames are checked for collisions; reserved runtime names are
diagnosed. Name collisions may be written for manual correction but
block subsequent wrapper generation. Unsupported operations stay in the
configuration with their diagnostics. This does not supply transport
implementations or resolve unsupported schema features.

Existing files are never overwritten, even if originally generated.
Review changes and manually incorporate the desired YAML edits. Apply
with no new files is a no-op. This is initial scaffolding, not automatic
schema-refresh reconciliation. No helper, package metadata, wrappers, or
tests are created by this function; use initialize_client for a new
package.

## See also

`initialize_client`, `generate_client`, `load_project`

## Examples

``` r
schema <- system.file('catalogue/schema.json', package = 'specmill')
proposal <- configure_client(tempfile(), schema, package = 'catalogueclient')
proposal$files[['apis/default.yml']]
#> [1] "id: catalogueclient\n# Local schema files; patterns are file globs, exclude matches basenames by regex.\n# All paths resolve from the package root.\nschemas:\n  files:\n  - schema/openapi.json\n  patterns: []\n  exclude: []\n# An operation must pass methods AND include AND not match exclude (path regexes).\n# Keep only GET and POST below to omit PUT/PATCH/DELETE wrappers.\n# Leave their include/name entries in place; regeneration removes unchanged owned output.\n# An empty include selects nothing; remove include to allow every matching operation.\nselection:\n  methods:\n  - GET\n  - POST\n  - PUT\n  - PATCH\n  - DELETE\n  - HEAD\n  - OPTIONS\n  - TRACE\n  exclude: []\n  include:\n  - GET /items\n  - POST /items\n  - GET /items/{item_id}\n  - POST /refresh\n# Edit the public R function names here; keys stay METHOD /original/path.\nnames:\n  GET /items: list_items\n  POST /items: create_item\n  GET /items/{item_id}: get_item\n  POST /refresh: refresh\n# Shared operation settings. Per-operation settings below override these.\n# file groups wrappers in one R file; omit it for one file per function.\n# Example: add file: R/endpoints.R under defaults.\n# docs can set title, description, return, parameters, examples, tags and lifecycle.\ndefaults: {}\n# Optional overrides keyed by METHOD /original/path. Replace {} with entries.\n# Each entry can set file, helper, parameters, parameter_order and docs.\n# parameters keys use the original location and name, e.g. \"query limit\".\n# Example parameter setting: {name: max_results, default: 10, description: Maximum results.}\n# Advanced facades use inputs, extra_parameters and request.arguments mappings.\noperations: {}\n# Inherited from specmill.yml; uncomment to override for this service:\n# helper: api_request\n# documentation: true\n# Optional hooks: define client functions before enabling these settings.\n# hooks: {} # Public wrapper name -> pre_request/post_response hook-name sequences.\n# hook_callback: run_hook\n# hook_config: inst/hooks.yml # Alternative to inline hooks, not both.\n# prepare: prepare_operation # Development callback; pass an explicit callbacks environment.\n# policy_version: \"1\" # Your review label, recorded in generation metadata.\n# Optional fixed request expectations for generated tests:\n# contracts: {} # Public wrapper name -> fixed request expectations.\n# contracts_file: tests/testthat/contracts.rds\n# response_fixture: {} # Mock response used by inline single-call contracts.\n# Full configuration examples: https://seanthimons.github.io/specmill/articles/configuration.html"
```
