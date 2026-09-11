# Handoff: specmill multi-API capability work

**Generated**: 2026-09-11 17:26 -04:00
**Branch**: `feat/multi-api-initialization`
**Status**: Ready for review; capability implementation remains open

## Goal

Crosswalk the proving-ground audit against open issues and give the next
implementer reproducible evidence, scoped work, and explicit verification.
The user is reviewing the README; leave both READMEs unchanged during this task.

## Completed

- Multi-API initialization and follow-up fixes are committed through `ee2dafc`.
- Audit and reproduction script committed as `006885d`: 421 renderable operations,
  127 diagnostics, 118 capability gaps, nine definite AMOS source defects.
- CHET collision repaired in the proving ground with one explicit YAML name
  override; no source-schema or generated-wrapper edits.
- Opened #14 JSON shapes, #15 diagnostics, #16 source-contract review, and #17
  configuration name collisions. Existing #4 and #6–#13 remain open.
- Added `dev/audits/proving-ground/ISSUE-CROSSWALK.md` with ownership/dependencies.

## Not Yet Done

- Implement #14, the highest-coverage slice (84 standalone blockers, two mixed
  with #8). These counts are first blockers, not guaranteed coverage gains.
- Complete the broader capability matrix (#6) and request-level testing (#7).
- Resolve flagged service contracts (#16) before guessing their wire encoding.
- Merge/release this branch only when requested; README installs stable v0.1.4,
  which is not the audited development snapshot.

## Failed Approaches

An initial audit classified Swagger 2 body arrays without `items` as defects.
That rule belongs to non-body parameter contexts; body schemas inherit Draft 4
unconstrained-item semantics. Corrected classification is 118 gaps / nine defects.
Do not restore the earlier 110/17 split or interpret `items: {}` as a missing body.
CHET's duplicate operation ID blocked full preview until the name override below.

## Key Decisions

| Decision | Rationale |
| --- | --- |
| Preserve reviewed YAML and client-owned helpers | Users should customize through configuration without editing generated wrappers |
| API keys and issued bearer tokens first | OAuth login/refresh remains explicitly deferred in #4 |
| Separate schema defects from generator gaps | Guessing replacements can generate plausible but incorrect requests |
| Test serialized requests, not only helper calls | Generation and HTTP success do not establish API correctness |

## Current State

**Working:** Full plan succeeds, both distinct CHET names are present, and audit
assertions verified that plan mode left project files unchanged. No live API
requests were made for the audit.

**Unsupported:** See the 127 operation-level rows in the committed audit. The
audit is not exhaustive validation of all 548 operations or all schema versions.

**User changes:** `dev/build_petstore.R` was deleted by the user before this task.
Do not restore, stage, or commit that deletion incidentally. Check `git status`
on resume for additional changes. The handoff/crosswalk are the only tracked
files changed in the issue-crosswalk follow-up.

## Files to Know

| File | Role |
| --- | --- |
| `dev/audits/proving-ground/ISSUE-CROSSWALK.md` | Issues, ownership, sequencing, validation boundaries |
| `dev/audits/proving-ground/README.md` | Findings, ranked coverage, schema semantics and citations |
| `dev/audits/proving-ground/operations.csv` | Per-operation evidence, review flags and classifications |
| `dev/audits/proving-ground/schemas.csv` | 27 input snapshot hashes |
| `dev/audit_proving_ground.R` | Interactive reproduction function; targeted corpus audit, not a general validator |
| `R/operations.R`, `R/input_schema.R`, `R/context.R` | Active metadata path; `R/context.R::local_ref()` is the resolver to trace |
| `R/body_shapes.R` | `supported_body()`, `body_fixture()`, `body_checks()` all need coherent JSON shape support |
| `R/generation.R`, `inst/templates/request.R` | Wrapper rendering and generated HTTP serialization |
| `R/configuration-scaffold.R`, `R/api-catalogue.R`, `R/initialization.R`, `R/multi-api.R` | Naming/configuration review and per-API helper generation |
| `tests/native-transport.R`, `tests/authentication.R` | Existing base-R acceptance functions and local HTTP test infrastructure |

## Code Context and Reproduction

Proving ground: `C:/Users/sxthi/Documents/specmill-testing`, package `forgetest`.
Its build script and generated configuration hold reviewed API names, base URLs,
authentication, and batch settings. Download origins came from
`C:/Users/sxthi/Documents/ComptoxR/R/schema.R` and related service metadata.
Do not assume schema filenames or relative server URLs uniquely identify APIs.

The existing `apis/chet_forgetest.yml` mapping is:

```yaml
OPTIONS /reaction/batchsearch: chet_default_api_reaction_batchsearch_options
```

The map operation retains `chet_default_api_reaction_map_dl_options`.
Do not remove the override while investigating #17.

```r
# From the specmill checkout, with the matching development package installed:
source('dev/audit_proving_ground.R')
a <- audit_proving_ground(
  'C:/Users/sxthi/Documents/specmill-testing',
  output = '.docs-lib/proving-ground-next'
)
stopifnot(
  length(a$plan$operations) == 421L,
  nrow(a$diagnostics) == 127L,
  sum(a$diagnostics$classification == 'schema_defect') == 9L
)
```

Those are pre-implementation expectations. After a fix, compare operation keys
and newly exposed reasons against the baseline rather than keeping stale counts.
The audit calls installed `specmill`, not automatically the checkout's R files.

## Resume Instructions

1. Read this handoff and crosswalk; run `git status --short` and inspect recent
   commits. Preserve user changes and refresh the owning GitHub issue.
2. For #14, trace metadata through body validation, fixtures, rendering, and HTTP
   serialization before editing. A parser-only acceptance change is incomplete.
3. Add a minimal deterministic regression schema using the existing test style;
   assert the actual request body and invalid-input behavior.
4. Run targeted acceptance tests and appropriate package checks for shared
   generator/helper changes. Then rerun the audit into a separate directory.
5. Record changed operation keys, remaining blockers, and verification in the
   owning issue before closure. No issue was closed by this audit.

## Setup, Edge Cases, and Warnings

- Windows / PowerShell, R 4.5.1; use `LC_ALL=C` for consistent batch output.
  Prefer sourceable R scripts; avoid PowerShell interpolation of R `$` access.
- Existing tests use base-R acceptance scripts; do not invent a testthat layout.
- Audit reproduction requires the local schema/config corpus; new regression
  tests must run offline without that folder or real credentials.
- Preserve `{}` versus `[]`, null versus omission, typed maps, and closed objects.
  Do not treat examples as authoritative type declarations.
- #16 tracks nine AMOS defects, ten GET-body declarations, eleven binary-query
  declarations. Groups overlap. Do not silently convert requests or source types.
- The audit's modeled GET/POST and non-admin policy was never applied to YAML.
- `.docs-lib/`, `evidence/`, and `artifacts/` are ignored. `docs/` is a historical
  documentation checkout; do not edit it for this work.

## Project Maintenance Context

specmill generates and maintains R API clients from local schemas and reviewed
project policy. It is a development tool; generated clients own their HTTP
helpers, authentication, response handling, and runtime hooks.

The current name is **specmill**, selected on 2026-09-10. This is a complete
rename, including ComptoxR: package namespace, specmill.yml, .specmill ownership
records, recovery paths, callbacks, fixtures, commands, CI, and documentation.
There is no fallback to the former package name or storage paths.

The README and six guides in vignettes/ are the current usage documentation.
Exported functions are documented in man/. Use the bundled
catalogue for new-client acceptance; use ComptoxR for existing-client acceptance.

Validation covers R CMD check, executable guides, independent fixed contracts,
unchanged client wrapper behavior, and a second generation apply with no changes.
Keep the toolkit source archive and ComptoxR's dev/toolkit-lock.json in sync.

Historical migration plans and results remain in Git history and evidence/.
They record earlier releases and are not instructions to restore old branding.
