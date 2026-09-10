# Load and validate a YAML project

Resolve local schemas and service policies from an explicit client root
without generating output.

## Usage

``` r
load_project(root, config = "specmill.yml", callbacks = new.env(parent = emptyenv()))
```

## Arguments

- root:

  Explicit existing client root directory.

- config:

  Project YAML path relative to root. Defaults to specmill.yml.

- callbacks:

  Explicit environment containing named development callbacks.

## Value

A list containing named services, input file paths, normalized root,
package name, and optional formatter policy. Each service contains
resolved schema files and validated generation policy.

## Details

Paths inside project and service YAML resolve against root. Services
require unique IDs, local schema selectors, and a client helper name.
Unknown fields, invalid types, unsafe paths, executable YAML tags,
unresolved callbacks, and invalid selectors fail. callback_files are
fingerprinted inputs, not sourced scripts.

## See also

[Step-by-step
guide](https://seanthimons.github.io/specmill/articles/configuration.html).
