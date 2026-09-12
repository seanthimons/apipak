# Issue #12: JSON request-body composition

Implementation: `c13e865`, verified on 2026-09-11.

The supported slice accepts ordinary JSON-shaped R values for `oneOf`, `anyOf`,
and `allOf`, including nested properties, array items, and typed maps. A value
must match exactly one, at least one, or all branches respectively; sibling
constraints also apply. No discriminator dispatch, schema flattening, coercion
between `{}` and `[]`, or inference of types from examples is performed.

OpenAPI 3.1 type arrays and null types are supported for JSON bodies. OpenAPI 3.0
typed `nullable` values retain enum and composition constraints. Required null
values differ from absent fields/bodies. Unsupported JSON assertion keywords and
malformed supported constraints remain operation-specific diagnostics. Parameter
and form compositions, boolean schemas, recursive inputs, and generated response
validation remain outside this slice. Response schemas are retained as metadata.

Local references retain cycle detection, a 100-reference depth limit, and
containing-file base paths; remote references are never fetched. OpenAPI 3.1
local assertion siblings are conjunctive, while annotation siblings retain
ordinary parameter shapes. Bundled assertion siblings require explicit `allOf`
instead of silently replacing referenced constraints.

## Live proving ground

The unchanged 27 API YAML files / 69 groups improve from **328 to 332 renderable**;
205 exclusions remain, and blockers decrease from 15 to 11. All four requested
live composition contracts now render, generate validated fixtures, and invoke
a recording helper:

- `POST /api/amnb_nate`
- `POST /api/ncc_cats`
- `POST /api/opera`
- `POST /api/predictor_models/predict`

There are **no newly exposed active blockers**. The four AMOS schema defects
remain separate under #16; the other seven remaining blockers retain their
binary-parameter/source-contract review reasons (six also involve nested query
objects). Names, configuration, helpers, and source files were preserved.

[Exact gained keys](active/gained-operations.csv),
[fixture invocations](active/fixture-invocations.csv),
[exposed blockers](active/exposed-blockers.csv),
[remaining diagnostics](active/operations.csv).

## Additional schemas

The 33 mirrored inputs improve from **4,514 to 4,752 smoke passes** (+238),
with no formerly passing operation becoming blocked. There are 4,878 renderable
operations, 426 parser diagnostics, and 126 fixture failures. All sources retain
their hashes; no document newly aborts.

| Input | Previous smoke passes | Current smoke passes |
| --- | ---: | ---: |
| GitHub 3.0 | 1,121 | 1,181 |
| GitHub 3.1 | 1,035 | 1,121 |
| DigitalOcean | 583 | 641 |
| Box | 256 | 286 |
| Multi-file petstore | 3 | 4 |
| composed-schemas.yaml | 0 | 2 |
| Stripe, with existing bracket policy | 237 | 237 |
| Kubernetes | 1,195 | 1,195 |

The [339 changed operation records](additional/changed-operations.csv) include
234 parser-to-pass gains, four repaired fixture failures, 43 parser-to-fixture
transitions, and 58 existing fixture failures whose message changed. The last
58 are **not newly exposed blockers**.

Examples of gained keys: multi-file petstore `POST /pets`, composed-schemas
`PATCH /pets` and `PATCH /pets-filtered`, GitHub 3.1
`POST /repos/{owner}/{repo}/issues` and
`PATCH /repos/{owner}/{repo}/issues/{issue_number}`, and Box `POST /ai/ask`.
[All 238 gained keys](additional/resolved-operation-keys.csv) identify the source
file as well as the HTTP method/path.

The [43 newly exposed fixture blockers](additional/newly-exposed-fixture-blockers.csv)
comprise 23 GitHub 3.1, seven GitHub 3.0, 12 DigitalOcean, and one Box operation.
Parsing/rendering now succeeds, but finite candidate synthesis cannot produce
a fully valid body; these require reviewed fixture overrides or future fixture
work, and are not counted as passes. Examples include GitHub
`PATCH /app/hook/config`, DigitalOcean
`DELETE /v2/firewalls/{firewall_id}/rules` and `POST /v2/droplets/actions`, and Box
`POST /file_requests/{file_request_id}/copy`. No new parser blocker was exposed.

[Full schema totals](additional/schemas.csv),
[all operation results](additional/operations.csv),
[source hashes](additional/sources.csv).

## Reproduction and checks

After installing this checkout:

```r
source('tests/composition-constraints.R'); composition_constraints_acceptance()
source('tests/composition-transport.R'); composition_transport_acceptance()
source('dev/verify_composition.R'); verify_composition()
```

Package tests are offline, use temporary generic schemas, and do not depend on
the proving-ground folder. The composition transport check reuses
`tests/native-transport.R` and asserts the exact JSON bytes received by localhost,
including rejected inputs producing no HTTP request. It covers live-style
alternatives, nested identifiers, overlapping branches, sibling constraints,
local references, explicit null/omission, empty containers, and fixture overrides.

The constraint check covers JSON structural equality, shape-specific assertions,
both exclusive-bound dialects, invalid scalar inputs, unsupported/malformed
keywords, type unions, form boundaries, 100-branch fanout, and a 25-level `allOf`
fixture chain. Candidate enumeration reuses branch results; fixture synthesis
remains finite and requests a reviewed override when no candidate validates.

Targeted regressions include native/form/parameter/bracket transport, local
references, schema versions/stress, mappings, and diagnostic propagation.
The clean-source `R CMD check --no-manual` completed with **zero errors, warnings,
or notes**, including all **37 acceptance scripts** and rebuilt vignettes.
[Package check log](package-check.log). The check-result object was also asserted
programmatically. A separate Quarto version-query warning appeared afterward
while collecting session information; it is not a package-check finding.
Installation and `git diff --check` passed.
The corpus audit uses recording helpers rather than live APIs; it does not
establish response validation or live service compatibility. Source hashes are
checked before and after the audit. The mirrored Stripe input retains the
previous explicit bracket option so comparisons use the same policy.

Changed implementation files: `R/body_shapes.R`, `R/input_schema.R`,
`R/context.R`, `R/schema_references.R`, and the JSON/form capability selection
in `R/operations.R`. The request helper template and generated function names
are unchanged. The configuration vignette documents the supported slice;
composition, reference, and mapping acceptance tests capture the new behavior.

Semantics: [JSON Schema composition](https://json-schema.org/understanding-json-schema/reference/combining),
[OpenAPI 3.0 Schema Object](https://spec.openapis.org/oas/v3.0.4.html#schema-object).
