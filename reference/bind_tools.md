# Bind legacy maintenance tools to a client context

Install an extracted compatibility function group into an explicit
client policy environment.

## Usage

``` r
bind_tools(group, envir)
```

## Arguments

- group:

  Installed compatibility function group.

- envir:

  Explicit client context receiving installed functions.

## Value

The supplied environment invisibly, with bound functions added. Unknown
groups or a non-environment target raise an error.

## Details

This is for existing endpoint-table integrations, not new project setup.
Groups include schema, paths, inventory, scaffold, test_inventory,
test_scaffold, test_validation, test_helpers, ast, runner, parser,
drift, diff, and readiness. The client supplies required selection,
rendering, fixture, and reporting policy. For readiness use
asNamespace("specmill") as the parent and initialize audit_policy with
the bound read_audit_policy() helper. Other groups also install
supporting dependency exports where absent.

## See also

[Step-by-step
guide](https://seanthimons.github.io/specmill/articles/troubleshooting.html).
