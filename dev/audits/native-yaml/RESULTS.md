# Native schema ingestion (#18)

Implemented in `bfb62ce`; verified 2026-09-11 with the installed development package.

The package now loads JSON, YAML, and YML through a shared document reader. YAML
uses YAML 1.2 scalar semantics via `yaml12`; the existing `yaml` dependency checks
duplicate keys and incompatible explicit tags without performing scalar coercion.
No Python process or converted JSON file is needed. New single- and multi-API
clients retain the YAML source extension. Existing JSON filenames and client-owned
helpers are preserved.

## Corpus comparison

All 33 original primary downloads were audited directly. All **26 YAML documents
loaded without scalar-coercion warnings**. Operation extraction completes for 23;
the other three reach existing webhook-only, OpenAPI 3.2, or GitHub parser limits.

There are **zero changed operation keys, stages, or diagnostic reasons** relative
to the historical converted-JSON baseline. No newly exposed blocker was found.
Document-level errors match after normalizing the original versus temporary file
paths in error messages. The original source files have unchanged hashes.

| Stage | Converted JSON baseline | Native sources |
| --- | ---: | ---: |
| Selected/rendered operations | 2,186 | 2,186 |
| Operation diagnostics | 660 | 660 |
| Generated fixtures | 2,185 | 2,185 |
| Wrapper invocations against recording helper | 2,183 | 2,183 |
| Smoke passes excluding unresolved operation refs | 1,524 | 1,524 |

The 659 DigitalOcean operation references still produce empty wrappers and are
excluded from meaningful smoke coverage. Both GitHub documents still abort at the
same parser locations. The two `list` wrapper collisions and Box thumbnail fixture
failure remain. Stripe's 594 form-body blockers, other body compositions, recursive
references, OpenAPI 3.2, and webhook-only support are unchanged. Four JSON Schema
test arrays remain non-OpenAPI inputs. See the
[historical findings](../additional-schemas/RESULTS.md) for exact affected keys.

The active 27-API / 69-group proving ground was also audited read-only and remains
**328 renderable / 205 excluded / 15 blocked**. Its file hashes and exact blocker
keys are unchanged, including the separate four AMOS defects under #16.

## Verification

- `tests/schema-document.R`: JSON/YAML shape and scalar equivalence, empty maps
  versus arrays, null versus omission, UTF-8, integer boundaries and double
  precision parity, scientific notation, and 1,000 alias references. Rejects
  duplicates, non-finite numbers, unsupported keys/tags, incompatible tagged node
  kinds, merge keys, multiple documents, unresolved aliases, and cycles.
- `tests/schema-loading.R`: equivalent operations/diagnostics/fixtures/wrappers
  across JSON/YAML/YML; initialization, generation plan/apply/check, catalogue
  identity and repeated discovery, multi-API source extensions, schema diffs, and
  preserved configuration/helper/source content. Tests are offline and independent
  of the external proving ground.
- Independent review reproduced malformed standard tags accepted by the parser;
  validation now rejects those cases and regression coverage verifies the fix.
- Clean-source `R CMD check --no-manual` passed with zero errors, warnings, or
  notes, including all 30 acceptance scripts and vignette rebuilds. The final
  configuration vignette also rendered separately. A local Quarto version-query
  warning followed the successful package check and is not a check warning.

## Reproduce

Install the checkout, then run:

```r
source('dev/verify_native_schemas.R')
verify_native_schemas()
source('tests/schema-document.R'); schema_document_acceptance()
source('tests/schema-loading.R'); schema_loading_acceptance()
source('dev/verify_parameter_serialization.R')
verify_parameter_serialization(output = '.docs-lib/native-yaml-active-audit')
```

The direct native audit uses the download manifest, not the Python conversion
step. Each schema has a 180-second isolated-process timeout. As before, wrapper
invocation uses a recording helper: these counts do not claim full HTTP, response,
authentication, or reference-bundling support.

[Exact operation records](operations.csv), [changed operations (empty)](changed-operations.csv),
[document comparison](document-comparison.csv), [source URLs/hashes](sources.csv).
