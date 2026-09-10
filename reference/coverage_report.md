# Report implementation coverage and test gaps

Inspect a configured client and prepare or write client-owned coverage
badges, baselines, and fixed-contract gap reports.

## Usage

``` r
coverage_report(root, policy, callbacks = new.env(parent = emptyenv()),
    config = "specmill.yml", mode = c("plan", "apply"))
test_gap_report(root, policy, callbacks = new.env(parent = emptyenv()),
    config = "specmill.yml", mode = c("plan", "apply"))
```

## Arguments

- policy:

  Client report-policy list or YAML filename. See details for required
  fields.

- root:

  Explicit existing client root directory.

- mode:

  Check or plan without writes; apply validated output.

- config:

  Project YAML path relative to root, or client hook configuration for
  hook validation.

- callbacks:

  Explicit environment containing named development callbacks.

## Value

coverage_report() invisibly returns baseline values, outputs, and badge
records. test_gap_report() invisibly returns timestamp,
manifest_authoritative, manifest_replacement, gaps_count, gaps, and
stale_protected. Apply also writes the corresponding files.

## Details

Both functions default to read-only plan. Coverage policy has baseline
and groups; each named group has services (a regex), label, and badge
path, and groups must partition configured services. Test-gap policy has
helpers, report_dir, and readiness_report. String policy filenames are
resolved against the R working directory; use explicit paths. Coverage
counts declarations/files, not passing tests. Apply overwrites the
report destinations and writes GitHub summary outputs; report files are
not reconciled through the generated-file manifest.

## See also

[Step-by-step
guide](https://seanthimons.github.io/specmill/articles/maintenance.html).
