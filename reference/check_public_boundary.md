# Check client public-release boundaries

Check client-defined host, artifact, export, and schema restrictions
without loading the client.

## Usage

``` r
check_public_boundary(root, policy, schema_names = NULL)
```

## Arguments

- policy:

  Public-boundary policy list or explicit YAML filename; see details for
  accepted fields.

- schema_names:

  Selected public operation names; NULL skips membership checks for
  built artifacts.

- root:

  Explicit existing client root directory.

## Value

Invisibly TRUE after printing a scan summary; raises an error when a
policy restriction fails.

## Details

Policy accepts forbidden_hosts, forbidden_files, forbidden_exports,
forbidden_schemas, and api_exports regex strings plus a manual_exports
sequence. With schema_names supplied, selected API exports must have an
approved schema or manual mapping. Source scans include untracked
nonignored files in Git projects. String policy filenames resolve
against the R working directory.

## See also

[Step-by-step
guide](https://seanthimons.github.io/specmill/articles/maintenance.html).
