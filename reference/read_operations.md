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

  A list with optional service identity, methods allowlist, path exclude
  regexes, names keyed by METHOD /path, and override_keys for declared
  operation settings.

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

The supported subset includes scalar path/query input and JSON scalar,
nested declared-object, and nested array bodies. External/cyclic input
references, unsupported media, and unsupported parameter/body shapes are
diagnosed. Structurally valid unsupported metadata is returned
separately for reviewed client mapping. This is not a full schema
validator. Comparison classifies input changes conservatively and cannot
prove HTTP or response compatibility.

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
