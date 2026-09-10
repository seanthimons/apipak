# Validate client runtime hook declarations

Check declared hook chains against wrapper calls, client hooks, and the
configured hook executor.

## Usage

``` r
validate_hooks(config, wrappers, hooks, callback = "run_hook")
check_client_hooks(root, config, hooks, callback = "run_hook")
```

## Arguments

- root:

  Explicit existing client root directory.

- config:

  Parsed client runtime hook configuration as a named list; not a
  project YAML path.

- wrappers:

  Named client functions parsed once by the caller.

- hooks:

  Explicit environment of local hook functions.

- callback:

  Name of the client's hook execution function.

## Value

validate_hooks() returns valid, errors, and counts for functions, hooks,
and parameters. check_client_hooks() raises an error for invalid
declarations and otherwise returns that result invisibly.

## Details

config is parsed hook policy data, not a filename. validate_hooks()
takes an explicit named list of wrapper functions. check_client_hooks()
parses definitions under root once and constructs the wrapper list
without loading the client package. The hooks environment supplies the
client hook functions. Validation is structural; behavioral hook tests
remain necessary.

## See also

[Step-by-step
guide](https://seanthimons.github.io/specmill/articles/configuration.html).
