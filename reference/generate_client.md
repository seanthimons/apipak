# Plan, generate, and check client output

Generate wrappers, documentation, and supplied fixed contract tests from
YAML or a legacy R-list specification.

## Usage

``` r
generate_client(root, spec = NULL, mode = c("check", "plan", "apply"),
    config = NULL, callbacks = new.env(parent = emptyenv()),
    adopt = list(), artifacts = c("wrappers", "tests", "documentation"))
```

## Arguments

- root:

  Explicit existing client root directory.

- spec:

  Client specification with files, helper, optional hooks and renderer.

- mode:

  Check or plan without writes; apply validated output.

- config:

  Project YAML path relative to root, or client hook configuration for
  hook validation.

- callbacks:

  Explicit environment containing named development callbacks.

- adopt:

  Reviewed legacy files as a named list of relative paths and SHA-256
  hashes of UTF-8/LF text without a final newline. Changed hashes fail;
  lifecycle and mixed-file protection still apply.

- artifacts:

  Output kinds to reconcile. Defaults to all; thin wrapper/test commands
  can select their own artifacts while retaining one generation
  contract.

## Value

A list with files (file/path/action records), configured operations,
drift, diagnostics, mapping_diagnostics, retained_diagnostics,
unused_hooks, inventory, retained_sources, and manifest (toolkit
version, input hashes, policy versions). File actions include write,
unchanged, protected, remove, and retained. Check errors on actions
other than unchanged or retained.

## Details

Supply exactly one of spec and config. Check is the default and errors
when reconciled output is stale or protected; plan returns file actions
without modifying the client; apply reconciles verified owned output.
Both read-only modes stage candidate output. Development callbacks must
be deterministic and are resolved only in callbacks. Unsupported
operations remain diagnostics and never authorize removal. Check success
does not establish complete schema support or passing tests. Adoption
accepts only individually reviewed current hashes and does not override
lifecycle or mixed-file protection.

## See also

[Step-by-step
guide](https://seanthimons.github.io/specmill/articles/maintenance.html).
