# Run sourceable maintenance commands

Adapt the shared generator to existing wrapper/test command flags and
locate a client root from a maintenance script.

## Usage

``` r
generation_command(root, args = character(), kind = c("stubs", "tests"),
    config = "specmill.yml", callbacks = new.env(parent = emptyenv()))
script_root(script)
```

## Arguments

- root:

  Explicit existing client root directory.

- script:

  Maintenance script basename, located from source frames or the Rscript
  command line.

- args:

  Character vector of command flags. Use explicit values when calling
  from a sourced interactive script.

- kind:

  `stubs` reconciles wrappers and documentation; `tests` reconciles
  fixed contract tests. Both default to apply.

- config:

  Project YAML path relative to root, or client hook configuration for
  hook validation.

- callbacks:

  Explicit environment containing named development callbacks.

## Value

generation_command() invisibly returns the generation result, or NULL
for help, and propagates errors. script_root() returns a normalized
absolute package root or errors if it cannot locate the script/package.

## Details

Unlike generate_client(), generation_command() defaults to apply. For
stubs use –plan or –check; for tests use –dry-run, –check, or –generate.
–help prints usage. Legacy –rebuild prefixes are accepted but selection
remains in YAML. –force never bypasses ownership. Test check/apply
requires fixed contracts for every selected operation. Summary values
are written to GITHUB_OUTPUT when set. script_root() walks upward from
the matching script to DESCRIPTION.

## See also

[Step-by-step
guide](https://seanthimons.github.io/specmill/articles/maintenance.html).
