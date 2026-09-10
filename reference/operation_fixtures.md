# Choose candidate operation inputs

Choose fixture values using reviewed overrides followed by schema
examples, defaults, enums, and type fixtures.

## Usage

``` r
operation_fixtures(operations, overrides = list())
```

## Arguments

- operations:

  Supported operation record or named list of records.

- overrides:

  Reviewed per-operation fixture input values.

## Value

A named list of per-operation input lists. Stops when a fixture cannot
be selected or fails supported constraints.

## Details

The selected value must satisfy supported type, enum, numeric,
string-length, and pattern constraints. An invalid selected candidate
raises an error rather than falling through to a lower-priority source.
Schema examples are never executed. Candidate inputs are not independent
expected request or response contracts.

## See also

[Step-by-step
guide](https://seanthimons.github.io/specmill/articles/testing.html).

## Examples

``` r
schema <- system.file('catalogue/schema.json', package = 'specmill')
operation_fixtures(read_operations(schema)$operations)
#> $get_item
#> $get_item$item_id
#> [1] "example"
#> 
#> $get_item$language
#> [1] "en"
#> 
#> 
#> $list_items
#> $list_items$page
#> [1] 1
#> 
#> 
#> $create_item
#> $create_item$body
#> $create_item$body$title
#> [1] "example"
#> 
#> $create_item$body$count
#> [1] 1
#> 
#> 
#> 
#> $refresh
#> named list()
#> 
```
