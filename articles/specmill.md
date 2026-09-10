# Start a new API client

specmill turns local API schemas and reviewed YAML policy into R
wrappers, documentation, and request contract tests. It is a
**development dependency**: people installing your generated package do
not need specmill. Your package owns HTTP requests, authentication,
response parsing, and runtime hooks.

This walkthrough creates a temporary catalogue client and checks it
without contacting a service. Every evaluated example runs when this
guide is built. For an existing package, including ComptoxR, use [Adopt
an existing
client](https://seanthimons.github.io/specmill/articles/existing-clients.md)
instead of initialization.

## 1. Install the development tools

Run this once in R. The tagged release makes the tutorial reproducible:

``` r

install.packages('remotes')
remotes::install_github('seanthimons/specmill@v0.1.4')
install.packages(c('httr2', 'testthat', 'devtools'))
```

If a project supplies an installer and toolkit lock, use those instead:
they select the version reviewed for that project. In a local specmill
source checkout, `devtools::install('.')` installs the checked-out
version. Start a fresh R session after changing an already loaded
version.

``` r

packageVersion('specmill')
#> [1] '0.1.4'
```

You also need R package build tools appropriate to your operating system
when installing dependencies from source. The tutorial itself needs no
credentials.

## 2. Choose a local schema and a new package directory

Use the bundled OpenAPI example first. It contains four operations: get
an item, list items, create an item, and refresh the catalogue.

``` r

schema <- system.file('catalogue/schema.json', package = 'specmill', mustWork = TRUE)
root <- tempfile('catalogue-client-')
```

`root` is temporary so this guide can be rerun. For your own project,
replace it with an unused permanent directory such as
`C:/projects/catalogueclient` or `~/projects/catalogueclient`, and
replace `schema` with your downloaded JSON schema. Save the schema’s
origin and version in your project; generation reads local files and
does not download or refresh schemas.

## 3. Initialize the package

Supply your own metadata and the service’s real base URL. The example
URL below is a placeholder and is never contacted in this guide.

``` r

created <- specmill::initialize_client(
  root, schema,
  package = 'catalogueclient',
  title = 'Catalogue API Client',
  author = list(given = 'Example', family = 'Maintainer', email = 'you@example.org'),
  license = 'MIT + file LICENSE',
  base_url = 'https://api.example.org'
)
list.files(root, recursive = TRUE, all.files = TRUE)
#> [1] ".Rbuildignore"           ".specmill/manifest.json"
#> [3] "apis/default.yml"        "DESCRIPTION"            
#> [5] "LICENSE"                 "NAMESPACE"              
#> [7] "R/api_request.R"         "schema/openapi.json"    
#> [9] "specmill.yml"
```

Initialization writes immediately and refuses existing-file conflicts.
It creates:

| File | What you maintain |
|----|----|
| `DESCRIPTION`, `LICENSE` | Package identity, dependencies, and your license |
| `R/api_request.R` | Client-owned httr2 transport; adapt authentication here |
| `schema/openapi.json` | Local copy of the schema |
| `specmill.yml` | Project version and selected service files |
| `apis/default.yml` | Schema selection, helper name, and generation policy |
| `NAMESPACE`, `.Rbuildignore` | Package exports and exclusion of development inputs |
| `.specmill/manifest.json` | Ownership hashes maintained by specmill |

It does not create a Git repository, README, test runner, or pkgdown
site for the client. Those are ordinary package maintenance tasks. Do
not rerun initialization to update a client; edit policy and regenerate
instead.

## 4. Inspect the schema and policy

``` r

parsed <- specmill::read_operations(file.path(root, 'schema/openapi.json'))
names(parsed$operations)
#> [1] "get_item"    "list_items"  "create_item" "refresh"
parsed$diagnostics
#> list()
cat(readLines(file.path(root, 'apis/default.yml')), sep = '\n')
#> id: catalogueclient
#> schemas:
#>   files:
#>   - schema/openapi.json
#> helper: api_request
#> documentation: yes
```

An empty diagnostics list means these operations fit the supported
parser subset. It does not prove the service works. Review diagnostics
before using real schemas; see [Supported schemas and
troubleshooting](https://seanthimons.github.io/specmill/articles/troubleshooting.md).

The service’s `documentation: true` enables roxygen comments, help
pages, and exports during generation.
[Configuration](https://seanthimons.github.io/specmill/articles/configuration.md)
explains how to select methods, exclude paths, name functions, and
improve their help and examples.

## 5. Preview changes before applying them

``` r

plan <- specmill::generate_client(root, config = 'specmill.yml', mode = 'plan')
data.frame(
  file = vapply(plan$files, `[[`, character(1), 'file'),
  action = vapply(plan$files, `[[`, character(1), 'action')
)
#>                       file action
#> 1             R/get_item.R  write
#> 2           R/list_items.R  write
#> 3          R/create_item.R  write
#> 4              R/refresh.R  write
#> 5                NAMESPACE  write
#> 6       man/create_item.Rd  write
#> 7          man/get_item.Rd  write
#> 8        man/list_items.Rd  write
#> 9           man/refresh.Rd  write
#> 10 .specmill/manifest.json  write
stopifnot(length(plan$operations) == 4L, !length(plan$diagnostics))
```

`plan` parses and stages candidate output without changing the client.
Review the file actions, `plan$drift`, and diagnostics. `write` means a
new or changed file, `unchanged` means current output, `protected` needs
your review, and `retained` means a proposed removal is being protected.
An eligible deletion appears as `remove`. Manifest metadata can also
appear in the plan.

## 6. Apply, then check reproducibility

``` r

applied <- specmill::generate_client(root, config = 'specmill.yml', mode = 'apply')
checked <- specmill::generate_client(root, config = 'specmill.yml', mode = 'check')
stopifnot(all(vapply(
  checked$files, function(x) x$action %in% c('unchanged', 'retained'), logical(1)
)))
```

You now have four wrapper files in `R/`, their help pages in `man/`, and
exports in `NAMESPACE`. `check` returns normally when output is current
and raises an error when it is stale or protected. It is the default
mode of
[`generate_client()`](https://seanthimons.github.io/specmill/reference/generate_client.md).
A successful check does not mean tests were run or that every selected
schema operation is supported; inspect diagnostics too.

Edit YAML policy or your client helper to change behavior. Editing a
generated wrapper makes its recorded hash differ and protects it from
replacement.

## 7. Verify a wrapper without sending HTTP

For this small demonstration, source the helper and one wrapper into a
private environment, then replace the helper there with a recorder. The
generated client source has no runtime dependency on specmill.

``` r

runtime <- new.env(parent = baseenv())
sys.source(file.path(root, 'R/api_request.R'), runtime)
sys.source(file.path(root, 'R/get_item.R'), runtime)
captured <- NULL
runtime$api_request <- function(...) {
  captured <<- list(...)
  list(id = 'item-1')
}
result <- runtime$get_item(item_id = 'item-1', language = 'en')
stopifnot(
  identical(result, list(id = 'item-1')),
  identical(captured, list(
    method = 'GET', path = '/items/{item_id}',
    path_params = list(item_id = 'item-1'), query = list(language = 'en'), body = NULL
  ))
)
result
#> $id
#> [1] "item-1"
```

This checks the wrapper-to-helper contract. Follow [Write and run
contract
tests](https://seanthimons.github.io/specmill/articles/testing.md) to
persist fixed expectations in the package and run them with testthat.
Transport tests are separate: they verify the final URL, headers,
serialized body, and response handling.

## 8. Install and use your client

After changing the helper to use your actual service and authentication,
run:

``` r

devtools::install(root)
help('get_item', package = 'catalogueclient')
catalogueclient::get_item(item_id = 'a-real-id', language = 'en')
```

The last call sends a real request. The default helper performs one
request, including when an argument is named `page`. It returns JSON as
R lists, text/SVG as strings, binary as raw bytes, and empty response
bodies as `NULL`. It raises errors for HTTP failures or malformed
nonempty JSON. Credentials, pagination, retry decisions, batching, and
service-specific validation belong in the client.

## 9. Save the project and maintain it

Commit the schema, YAML policy, client helper, generated
source/help/tests, and `.specmill/manifest.json` together. Keep the
manifest tracked: it establishes which output can be updated safely.
Keep credentials outside tracked files. Add a package test runner as
shown in the testing guide.

When a schema or policy changes, repeat **plan -\> review -\> apply -\>
check -\> tests**. See [Routine maintenance and
CI](https://seanthimons.github.io/specmill/articles/maintenance.md) for
thin commands, schema comparisons, coverage reports, and building
documentation for your client.
