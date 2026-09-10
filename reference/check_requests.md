# Check a fixed request and successful result

Call a wrapper and require exact equality with independently supplied
captured request and result expectations.

## Usage

``` r
check_requests(call, expected, capture, result)
```

## Arguments

- call:

  Zero-argument function that calls the wrapper.

- expected:

  Independent fixed expected request records.

- capture:

  Zero-argument function returning captured requests.

- result:

  Expected successful result.

## Value

Invisibly TRUE on success; raises an error on a request/result mismatch
or a failing call.

## Details

The call executes first; errors propagate. Both the captured request and
final result use identical() semantics, including types and classes.
Supply a recorder or mock so an offline check does not contact a
service.

## See also

[Step-by-step
guide](https://seanthimons.github.io/specmill/articles/testing.html).

## Examples

``` r
captured <- NULL
call <- function() {
  captured <<- list(method = 'GET', path = '/items')
  list(count = 0L)
}
check_requests(call, list(method = 'GET', path = '/items'),
  function() captured, list(count = 0L))
```
