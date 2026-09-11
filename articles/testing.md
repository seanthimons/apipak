# Write and run contract tests

A generated wrapper can call the right helper and still return the wrong
result or throw afterward. Fixed contract tests check successful
completion, exact helper arguments, call order/count, and the final
result. Write expectations from the reviewed API/helper contract,
independently of generated wrapper text.

This standalone example creates a temporary client and runs its
generated test offline. Install `httr2` and `testthat` first if they are
not available.

## 1. Prepare a client with one selected operation

``` r

schema <- system.file('catalogue/schema.json', package = 'specmill', mustWork = TRUE)
root <- tempfile('tested-client-')
created <- specmill::initialize_client(
  root, schema, package = 'testedclient', title = 'Tested Catalogue Client',
  author = list(given = 'Example', family = 'Maintainer', email = 'you@example.org'),
  license = 'MIT + file LICENSE', base_url = 'https://api.example.org'
)
service_path <- file.path(root, 'apis/default.yml')
service <- yaml::read_yaml(service_path)
service$schemas$files <- as.list(service$schemas$files)
service$selection <- list(include = list('GET /items/{item_id}'))
yaml::write_yaml(service, service_path)
```

For your real client, use its existing root and selection policy. Do not
narrow selection simply to hide missing tests. Here the teaching client
intentionally has just `get_item()`.

## 2. Save independent fixed expectations

An RDS contract preserves R types and classes. `calls` is an ordered
sequence; each entry contains a helper name, its expected arguments, and
its mock response.

``` r

contracts <- list(
  get_item = list(
    inputs = list(item_id = 'item-1', language = 'en'),
    calls = list(list(
      helper = 'api_request',
      arguments = list(
        method = 'GET', path = '/items/{item_id}',
        path_params = list(item_id = 'item-1'),
        query = list(language = 'en'), body = NULL
      ),
      response = list(id = 'item-1', title = 'Example item')
    )),
    result = list(id = 'item-1', title = 'Example item')
  )
)
fixture <- file.path(root, 'tests/testthat/fixtures/contracts.rds')
dir.create(dirname(fixture), recursive = TRUE)
saveRDS(contracts, fixture)
cat('\ncontracts_file: tests/testthat/fixtures/contracts.rds\n',
    file = file.path(root, 'apis/default.yml'), append = TRUE)
```

Keys such as `get_item` are public wrapper names. Inputs use their
public R names. Specify types intentionally: `1L` is an integer, `1` is
a double, and exact expectations distinguish them. Use actual response
classes (for example tibbles) when preserving an existing client. Never
put credentials in fixtures.

Optional contract `environment` values are scoped environment variables
for the test, implemented with
[`withr::local_envvar()`](https://withr.r-lib.org/reference/with_envvar.html).
Add `withr` to that client’s test dependencies if using this field. Keep
environment values nonsecret.

## 3. Add the standard package test runner

Initialization declares testthat in `Suggests` but does not create its
runner. For this new client, create `tests/testthat.R`:

``` r

writeLines(c(
  'library(testthat)', 'library(testedclient)', "test_check('testedclient')"
), file.path(root, 'tests/testthat.R'))
```

Use your own package name. Existing packages should keep their current
runner and manual tests.

## 4. Generate and run the test

``` r

plan <- specmill::generate_client(root, config = 'specmill.yml', mode = 'plan')
stopifnot(!length(plan$diagnostics), length(plan$operations) == 1L)
applied <- specmill::generate_client(root, config = 'specmill.yml', mode = 'apply')
checked <- specmill::generate_client(root, config = 'specmill.yml', mode = 'check')
stopifnot(file.exists(file.path(root, 'tests/testthat/test-contract-get_item.R')))
```

The fixed sequence test reads the RDS fixture and replaces `api_request`
in the client namespace with a recorder. The placeholder URL is never
contacted.

``` r

testthat::test_local(root, filter = 'contract-get_item', stop_on_failure = TRUE)
#> ✔ | F W  S  OK | Context
#> 
#> ⠏ |          0 | contract-get_item                                              
#> ✔ |          2 | contract-get_item
#> 
#> ══ Results ═════════════════════════════════════════════════════════════════════
#> [ FAIL 0 | WARN 0 | SKIP 0 | PASS 2 ]
#> 
#> Way to go!
```

Use `stop_on_failure = TRUE` in automation. Merely exiting R
successfully is not enough if a test command only prints failures. In a
larger client, also run the existing bespoke tests for the helpers and
hooks you changed.

## 5. Inspect test coverage separately from execution

``` r

inspection <- specmill::inspect_client(root)
inspection$coverage
#> $testedclient
#> $testedclient$total
#> [1] 1
#> 
#> $testedclient$implemented
#> [1] 1
#> 
#> $testedclient$contracts
#> [1] 1
stopifnot(inspection$coverage$testedclient$contracts == 1L)
```

`implemented` counts selected named exports with source definitions.
`contracts` counts fixed contract declarations with generated test
files. Neither count says tests passed. Unsupported selected operations
stay in the coverage denominator; manual exports are reported
separately.

`generation_command(root, kind = 'tests', args = '--check')` also
requires fixed contracts for all selected operations. Its `--dry-run`
mode can show gaps before you finish authoring them. The core
[`generate_client()`](https://seanthimons.github.io/specmill/reference/generate_client.md)
generates supplied contracts without requiring every selected operation
to have one.

## Inline YAML contracts

For a simple single-call test, use `contracts` instead of an RDS file:

``` yaml
response_fixture: {id: item-1}
contracts:
  get_item:
    inputs: {item_id: item-1, language: en}
    request:
      method: GET
      path: /items/{item_id}
      path_params: {item_id: item-1}
      query: {language: en}
      body: null
    result: {id: item-1}
```

A contract can override `response_fixture`. Inline single-call tests use
`test-<operation>.R`; RDS sequence tests use
`test-contract-<operation>.R`. Prefer the latter when a manual test
already uses the simple name, multiple helper calls matter, or results
have R classes. Do not declare the same operation in both inline and RDS
contracts.

## Candidate input fixtures are not independent expectations

[`operation_fixtures()`](https://seanthimons.github.io/specmill/reference/operation_fixtures.md)
chooses candidate inputs in the order **override -\> example -\> default
-\> enum -\> type fixture**. It checks supported constraints and stops
if the chosen candidate fails them; it does not silently try a lower
priority value. Schema examples are never evaluated as R code.

``` r

operations <- specmill::read_operations(schema)$operations
candidate_inputs <- specmill::operation_fixtures(operations)
candidate_inputs$get_item
#> $item_id
#> [1] "example"
#> 
#> $language
#> [1] "en"
```

Review these values before using them against a service. They do not
establish expected helper calls or correct upstream results.
[`check_requests()`](https://seanthimons.github.io/specmill/reference/check_requests.md)
is a small alternative for checking one zero-argument call against a
capture function and independent result; see its reference example.

## Add the verification layer your change needs

| Layer | What to verify |
|----|----|
| Generation check | Committed output matches schema, policy, callbacks, and fixtures |
| Fixed helper contract | Successful wrapper result plus exact ordered helper calls |
| Hook tests | Validation, parameter changes, skip behavior, and post-processing |
| Local transport test | Final method, encoded URL, query/body placement, headers, media, and error decoding |
| Bounded live check | Current endpoint/authentication behavior using reviewed nonsecret input |

Use a local HTTP server or existing HTTP fixtures to test transport. Do
not re-record production traffic just to update generated tests. A live
failure can come from input, authentication, schema drift, generation,
runtime code, or an outage. Diagnose it before editing generated source
or relaxing expectations.
