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
#> [1] "id: catalogueclient\nschemas:\n  files:\n  - schema/openapi.json\nselection:\n  include:\n  - GET /items\n  - POST /items\n  - GET /items/{item_id}\n  - POST /refresh\nhelper: api_request\ndocumentation: yes\nnames:\n  GET /items: list_items\n  POST /items: create_item\n  GET /items/{item_id}: get_item\n  POST /refresh: refresh"
```
