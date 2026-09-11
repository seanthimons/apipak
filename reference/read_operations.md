# Read and compare local schema operations

Extract operation records from local OpenAPI 3.0/3.1 or Swagger 2.0 JSON
schemas and compare their input contracts.

## Usage

``` r
read_operations(files, policy = list())
compare_operations(old, new)
```

## Arguments

- files:

  Local JSON schema paths.

- policy:

  A list with optional service identity, methods allowlist, include
  allowlist of exact METHOD /path keys, path exclude regexes, names
  keyed by METHOD /path, and override_keys for declared operation
  settings. When include is supplied, an operation must match it as well
  as the method and path filters; an empty include selects nothing.
  Unknown included keys are errors.

- old:

  Results from `read_operations`.

- new:

  Results from `read_operations`.

## Value

read_operations() returns named operations and unsupported_operations
plus diagnostic and inventory lists. compare_operations() returns change
records with key, status (added, breaking, review, or unknown), and
reason; no changes returns an empty list.

## Details

The supported subset includes scalar path/query/header input, OpenAPI
form-style string query arrays, JSON scalar/nested-object/array bodies,
and binary string bodies sent as application/octet-stream. Binary inputs
are raw vectors. OpenAPI request bodies select application/json when
offered, including alongside other media types; alternative XML/form
encodings are not generated. External/cyclic input references,
unsupported media, and unsupported parameter/body shapes are diagnosed.
Structurally valid unsupported metadata is returned separately for
reviewed client mapping. Effective security requirements and resolved
security schemes are retained for generation. Authentication changes are
reported for review. Generated authentication is enabled by the
project's authentication environment-variable map; existing client
helpers remain responsible when that map is omitted. This is not a full
schema validator. Comparison classifies input changes conservatively and
cannot prove HTTP or response compatibility.

## See also

[Step-by-step
guide](https://seanthimons.github.io/specmill/articles/troubleshooting.html).

## Examples

``` r
schema <- system.file('catalogue/schema.json', package = 'specmill')
parsed <- read_operations(schema)
names(parsed$operations)
#> [1] "get_item"    "list_items"  "create_item" "refresh"    
stopifnot(length(compare_operations(parsed, parsed)) == 0L)
```
