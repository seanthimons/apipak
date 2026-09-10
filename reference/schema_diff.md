# Compare schema snapshots and format a change report

Compare explicitly selected schema files and method/path operations,
including reachable local references.

## Usage

``` r
schema_diff(old_dir, new_dir, pattern = "\\.json$", stage_priority = NULL,
    exclude_pattern = NULL, policies = list())
format_diff_markdown(diff_results)
count_diff_changes(diff_results)
```

## Arguments

- old_dir:

  Existing directory containing the previous schema snapshot.

- new_dir:

  Existing directory containing the candidate schema snapshot, using
  matching basenames.

- pattern:

  Regular expression selecting filenames; defaults to JSON files.

- stage_priority:

  Optional ordered suffix priority for files such as `service-prod.json`
  and `service-dev.json`. The first matching stage per service is
  selected. NULL disables stage selection.

- exclude_pattern:

  Optional case-insensitive filename exclusion regex, applied after
  selection by pattern.

- policies:

  Operation selection policies keyed by schema basename.

- diff_results:

  Versioned-schema report records. Changed contracts require review and
  are conservatively counted in the breaking-change lane; parsing errors
  stop comparison.

## Value

schema_diff() returns changed schema records containing schema_file plus
added, removed, and modified tables. format_diff_markdown() returns
report text. count_diff_changes() returns change counts, including the
conservative breaking-change count.

## Details

Use the same file naming and selection policy for both schema snapshots.
Changed canonical contracts require review and are conservatively
counted in the breaking-change lane. Malformed input stops comparison.
Policy changes should be reviewed separately from schema changes; these
reports do not prove upstream runtime compatibility.

## See also

[Step-by-step
guide](https://seanthimons.github.io/specmill/articles/maintenance.html).
