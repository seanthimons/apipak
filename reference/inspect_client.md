# Inspect implementation and fixed-contract coverage

Compare selected YAML operations with client source definitions,
exports, and fixed test files.

## Usage

``` r
inspect_client(root, config = "specmill.yml", callbacks = new.env(parent = emptyenv()))
```

## Arguments

- root:

  Explicit existing client root directory.

- config:

  Project YAML path relative to root, or client hook configuration for
  hook validation.

- callbacks:

  Explicit environment containing named development callbacks.

## Value

A list with operations, inventory, diagnostics, manual_exports, and
coverage. Coverage is keyed by service ID and contains total selected
operations, implemented exported definitions, and declared contracts
with test files.

## Details

This is a read-only structural inspection. Unsupported selections remain
in coverage totals. Manual exports are listed separately. A present test
file is not evidence that tests ran or passed.

## See also

[Step-by-step
guide](https://seanthimons.github.io/specmill/articles/testing.html).
