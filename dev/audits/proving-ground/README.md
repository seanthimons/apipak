# Multi-API proving-ground audit

Audited 2026-09-11 using specmill commit `ee2dafc`, package `forgetest`,
and the 27 schema snapshots in `specmill-testing/schema`.

The complete generation preview renders **421 operations** and reports **127
unsupported operations**, covering 548 operations in total. Among the diagnostics,
**118 are capability gaps and nine contain definite source-schema defects**.
This is a targeted audit of generation blockers, not a complete schema validator
or evidence that the generated functions work against the live services.

## Evidence and reproduction

- [operations.csv](operations.csv): all 127 diagnostics, classifications, contract
  review flags, and schema locations supporting the findings.
- [summary.csv](summary.csv): counts by reason, classification, and HTTP method.
- [schemas.csv](schemas.csv): input filenames and SHA-256 hashes.
- [Audit script](../../audit_proving_ground.R): reruns the generation preview and
  classification, checking that the preview leaves the project files unchanged.

Run from the specmill repository with the audited development version installed:

```r
source('dev/audit_proving_ground.R')
audit <- audit_proving_ground('C:/Users/sxthi/Documents/specmill-testing')
stopifnot(
  length(audit$plan$operations) == 421L,
  nrow(audit$diagnostics) == 127L,
  sum(audit$diagnostics$classification == 'schema_defect') == 9L,
  all(c(
    'chet_default_api_reaction_batchsearch_options',
    'chet_default_api_reaction_map_dl_options'
  ) %in% names(audit$plan$operations))
)
```

These assertions describe this snapshot; update the expectations when support or
inputs change. The script writes audit CSVs in this repository. It does not apply
wrapper generation or make live service requests.

## CHET collision resolved through configuration

CHET repeats `default_api_reaction_map_DL_options` as the operation ID for
`OPTIONS /reaction/map_DL` and `OPTIONS /reaction/batchsearch`. Operation IDs must
be unique within the API. See the [OpenAPI operation contract](https://spec.openapis.org/oas/v3.0.3.html#operation-object).

One existing entry in the proving ground's `apis/chet_forgetest.yml` was explicitly
edited to give the batch operation a unique exported name:

```yaml
OPTIONS /reaction/batchsearch: chet_default_api_reaction_batchsearch_options
```

The map operation retains `chet_default_api_reaction_map_dl_options`. The source
schema and generated R files were not edited. This source defect is separate from
the 127 unsupported-operation diagnostics below.

## Ranked capability work

Counts are observed first blockers, not guaranteed independent unlocks: resolving
one can reveal another. The optional useful-coverage column models GET/POST only
and excludes paths matching `^/admin(?:/|$)`; that policy was not applied to the
project configuration.

| Priority | Capability | Observed operations | Under modeled policy |
| --- | --- | ---: | ---: |
| 1 | Open JSON objects/maps and unconstrained item schemas | 84 | 73 |
| 2 | Multipart and URL-encoded bodies | 13 | 13 |
| 3 | Remaining query parameter shapes | 11 | 11 |
| 4 | Composed prediction bodies | 4 | 4 |
| 5 | Recursive ProtocolRecord schemas | 4 | 3 |
| Shared blocker | Query shapes plus open JSON objects | 2 | 2 |
| Upstream review | Invalid AMOS types | 9 | 9 |

**Start with JSON shape support.** Its 84 standalone blockers span 16 APIs:
73 open-object diagnostics and 11 currently labeled "Missing body schema."
Two further operations also need query support. Extend the parser, input checks,
fixtures, and serialization together; accepting metadata alone will not make the
generated request correct. Preserve JSON objects versus arrays, null values,
typed maps, and closed objects without inventing types from examples.

Multipart/form work follows [issue #9](https://github.com/seanthimons/specmill/issues/9).
Of its 13 operations, seven declare multipart and six URL-encoded bodies. Three
of the latter are GET requests requiring contract review.

Parameter serialization follows [issue #8](https://github.com/seanthimons/specmill/issues/8).
Eleven operations declare binary-looking file arrays in query parameters; verify
the intended wire format before treating those declarations as upload contracts.

Composition and recursion follow [issue #12](https://github.com/seanthimons/specmill/issues/12).
The four composed bodies belong to AMNB/NATE, NCC Cats, OPERA, and Predictor Models;
their scientific value could justify moving them ahead of query work. All four
recursive diagnostics involve local `ProtocolRecord` references in standardizer
protocol operations, despite the current "external or cyclic" wording.

## Schema defects versus weak diagnostics

The nine definite defects are all AMOS POST operations:

- Five upload/document operations use nested body properties with `type: file`.
- Three document-retrieval operations use `type: array of strings`.
- `/api/amos/search_for_document_ids/{record_type}` uses `dict` and
  `array of strings` as type names.

The latter names are not supported schema type keywords. Swagger 2 permits `file`
for form-data parameters, not arbitrary nested body properties. These need
upstream corrections or explicit verified overrides, not guessed conversions.
See [Swagger 2 parameters](https://spec.openapis.org/oas/v2.0.html#parameter-object)
and [Schema Objects](https://spec.openapis.org/oas/v2.0.html#schema-object).

The 11 "Missing body schema" diagnostics do have bodies. Six AMOS operations,
Mordred, and RDKit omit array item constraints in Swagger 2 body schemas. Their
Draft 4 semantics allow unconstrained items; the mandatory-items rule for Swagger
2 non-body parameters must not be applied to those bodies. See the
[Draft 4 items default](https://json-schema.org/draft-04/draft-fge-json-schema-validation-00#rfc.section.5.3.1.4).
ARN Cats, PFAS Atlas, and PFAS Cats explicitly use `items: {}`, an unconstrained
schema rather than an absent body. OpenAPI 3.0 requires the `items` field for array
schemas, but an empty Schema Object is allowed. See
[OpenAPI 3.0 Schema Objects](https://spec.openapis.org/oas/v3.0.3.html#schema-object).

Ten diagnosed GET operations declare request bodies. OpenAPI 3.0 says consumers
shall ignore request bodies where HTTP semantics are vague; these operations need
contract review rather than automatic body emission. See the
[operation specification](https://spec.openapis.org/oas/v3.0.3.html#operation-object).

## Validation boundary

The complete read-only generation preview succeeds after the CHET override, and
the runnable assertions verify counts and both distinct CHET names. No live API
calls, credentials, generated-wrapper edits, or package runtime changes were
needed for this audit. Full package checks were not repeated for report-only work.
Each subsequent capability needs deterministic request-level tests proving the
actual serialized URL/body, in addition to increased preview coverage.
