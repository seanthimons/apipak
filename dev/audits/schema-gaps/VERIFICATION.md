# Verification

Verified on 2026-09-11 with R 4.5.1 on Windows.

- Clean-source `R CMD check --no-manual`: **0 errors, 0 warnings, 0 notes**;
  all 34 acceptance scripts passed, including vignette builds and rebuilds.
- `tests/form-transport.R` reuses `tests/native-transport.R`. It verifies exact
  URL-encoded bytes and multipart part names, content types, filenames, repeated
  parts, raw/file bytes, JSON metadata, omission, required fields, explicit null
  rejection, media selection, Swagger formData, and unsupported encodings.
- The final media-aware fixture guard and `minItems: 0` form fixture adjustment
  landed after the check source was captured. The updated form transport test
  passed separately; the native corpus audit was rerun with those changes.
- `tests/media-types.R` verifies actual service YAML defaults/overrides and
  client-owned helper compatibility. `tests/new-client.R` verifies dependency
  checks before writes and preservation of existing helpers and DESCRIPTION.
- `tests/type-handling.R` covers missing/non-scalar types and operation-specific
  parser failures without losing healthy siblings.
- `tests/generated-names.R` verifies unchanged public names through real local
  HTTP, including a `list` wrapper, a `list` formal, array defaults/metadata,
  JSON bodies, and a `c` wrapper with vector mappings.
- `tests/local-references.R` covers path/operation/schema references, referrer
  base paths, internal references, pointer indices, missing/malformed dependencies,
  remote diagnostics, cycles, depth limits, bundled initialization independent
  of the original source directory, and dependency fingerprint invalidation.
- `tests/schema-stress.R` now verifies 35 selected / 8 diagnosed operations;
  the two new multipart keys are `POST /convert/cdx-to-mol` and
  `POST /ocsr/process-upload`.

Tests are offline, use temporary local data and localhost servers, and do not
depend on the external proving-ground folder. The separate audits read the
downloaded corpus without modifying it. The four AMOS schema defects remain
under #16. Composition/nullability work in #12 and configuration collision
review in #17 remain open.

The check runner's later Quarto version query emitted the existing local
`TMPDIR` command warning after `Status: OK`; the saved check result contains
zero errors, warnings, and notes.

To repeat the full check from a clean source staging directory:

```r
stage <- tempfile('schema-gaps-source-')
dir.create(stage)
stopifnot(all(file.copy(
  c('DESCRIPTION', 'NAMESPACE', 'LICENSE', 'R', 'man', 'inst', 'tests', 'vignettes'),
  stage, recursive = TRUE
)))
rcmdcheck::rcmdcheck(stage, args = '--no-manual')
```

To repeat the final targeted test and native-source audit after installation:

```r
source('tests/form-transport.R'); form_transport_acceptance()
source('dev/verify_schema_gaps.R'); verify_schema_gaps()
```
