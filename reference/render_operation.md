# Render one wrapper as R source text

Render an operation record with explicit helper, request, hook, and
documentation settings.

## Usage

``` r
render_operation(operation, spec)
```

## Arguments

- spec:

  Client specification with files, helper, optional hooks and renderer.

- operation:

  Supported operation record or named list of records.

## Value

A single character string containing generated wrapper source and
optional roxygen comments.

## Details

This low-level function returns text only; it does not validate an
entire project, run roxygen, write files, or check ownership. Prefer
generate_client() for normal maintenance. The default helper takes
method, path, path_params, query, and body. JSON array values should
remain R lists to preserve one-element arrays.

## See also

[Step-by-step
guide](https://seanthimons.github.io/specmill/articles/configuration.html).

## Examples

``` r
schema <- system.file('catalogue/schema.json', package = 'specmill')
op <- read_operations(schema)$operations$get_item
cat(render_operation(op, list(helper = 'api_request')))
#> # Generated with specmill; do not edit by hand.
#> get_item <- function(item_id, language = NULL) {
#>   if (is.null(item_id)) stop("Required input: item_id")
#>   params <- list("item_id" = item_id, "language" = language)
#>   result <- api_request(method = "GET", path = "/items/{item_id}", path_params = list("item_id" = params[["item_id"]]), query = list("language" = params[["language"]]), body = NULL)
#>   result
#> }
```
