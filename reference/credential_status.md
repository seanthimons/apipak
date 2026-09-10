# Check credential presence without exposing its value

Detect missing or placeholder credential strings without logging the
value or sending a request.

## Usage

``` r
credential_status(value, name = "credential")
credential_preflight(value, name = "credential", abort = TRUE, guidance = character())
```

## Arguments

- value:

  Credential string to inspect, usually read from an environment
  variable. Its value is never logged.

- name:

  Display label used in status messages.

- abort:

  Whether preflight should raise an error for invalid input. FALSE emits
  a warning instead.

- guidance:

  Character vector of client-owned credential setup instructions.

## Value

credential_status() returns valid and reason. credential_preflight()
returns TRUE/FALSE invisibly and emits a success message, warning, or
error according to status and abort.

## Details

These checks do not establish service authorization or key validity.
guidance contains client-owned setup instructions. With abort = FALSE,
preflight warns and returns FALSE instead of raising an error.

## See also

[Step-by-step
guide](https://seanthimons.github.io/specmill/articles/maintenance.html).

## Examples

``` r
credential_status('', 'service key')
#> $valid
#> [1] FALSE
#> 
#> $reason
#> [1] "service key is not set"
#> 
credential_status('your_key', 'service key')
#> $valid
#> [1] FALSE
#> 
#> $reason
#> [1] "service key looks like a placeholder or redacted value"
#> 
```
