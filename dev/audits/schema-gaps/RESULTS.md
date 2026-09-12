# Schema gaps: native corpus results

Implementation: `e9be960`, verified 2026-09-11. Three parallel implementation
tracks covered scalar type assumptions, generated-name masking, and local
references; form parsing, fixtures, configuration, and transport were integrated
with exact localhost wire tests. See [verification](VERIFICATION.md).

All 33 mirrored source documents were audited directly, including 26 YAML files.
No conversion shim, schema repair, example-derived types, live API calls, or
proving-ground configuration changes were used. Source hashes are unchanged.

| Stage | Native YAML baseline | Current |
|---|---:|---:|
| Selected/rendered operations | 2,186 | 4,390 |
| Operation parser diagnostics | 660 | 914 |
| Generated fixtures | 2,185 | 4,303 |
| Recording-helper invocations | 2,183 | 4,303 |
| Smoke passes with resolved references | 1,524 | 4,303 |

These are request-generation smoke checks, not complete API or response-contract
validation. Actual form, multipart, JSON, and parameter wire behavior is covered
separately by offline localhost tests. There are no remaining invocation-stage
failures in this corpus; 87 selected operations fail fixture generation.

## Changed operation keys

[changed-operations.csv](changed-operations.csv) contains **3,728 changed
operation records**, keyed by source file and HTTP method/path. Its comparison
includes resolution status, so it does not hide repaired DigitalOcean contracts
behind an unchanged historical `passed` label. Of previously visible records,
623 gained resolved smoke coverage; another 2,156 passing GitHub operations were
previously hidden by document aborts. All keys for the former group appear in
[resolved-operation-keys.csv](resolved-operation-keys.csv).

| Input | Previously meaningful passes | Current selected / diagnosed / passes |
|---|---:|---:|
| GitHub OpenAPI 3.0 | 0; document aborted | 1,146 / 83 / 1,121 |
| GitHub OpenAPI 3.1 | 0; document aborted | 1,095 / 134 / 1,035 |
| DigitalOcean | 0; 659 false passes | 583 / 76 / 583 |
| Stripe | 0 | 26 / 568 / 26 |
| Box | 251 | 258 / 39 / 256 |
| Multi-file Petstore | 2 | 3 / 1 / 3 |
| `allOf.yaml` | 0 | 1 / 0 / 1 |
| `allOf_composition.yaml` | 0 | 1 / 0 / 1 |

- Both GitHub documents retain all **1,229 declared operations** and complete
  operation extraction. Fixing type assumptions exposes remaining constraints;
  it does not imply all 2,458 operations are supported.
- DigitalOcean `GET /v2/1-clicks` now resolves its operation file and generates
  the referenced inputs. The 583 repaired passes are counted; 76 former false
  passes now carry concrete diagnostics.
- `GET /person/display/{personId}` passes in both allOf fixtures. Its public
  function remains `list`; generated constructors and validators no longer
  resolve through that wrapper. This fixes masking, not request composition.
- Multi-file Petstore `GET /pets` now passes with resolved parameter metadata.
  `POST /pets` resolves its body reference but exposes a body-composition blocker.
- The frozen natural-products acceptance schema independently gains
  `POST /convert/cdx-to-mol` and `POST /ocsr/process-upload` multipart support:
  35 selected and 8 diagnosed operations, with the source snapshot unchanged.

## Newly exposed blockers

[new-blockers.csv](new-blockers.csv) records **863 newly visible or changed
parser blockers and 86 new fixture blockers**, with exact keys and reasons.
These are not 863 newly lost operations: most were previously hidden by an
earlier blocker or a whole-document abort.

The GitHub documents expose 217 parser blockers and 85 fixture blockers. Examples
include `GET /advisories` (parameter composition),
`DELETE /orgs/{org}/secret-scanning/custom-patterns` (body shape),
`POST /markdown/raw` (unsupported media), and
`DELETE /orgs/{org}/actions/hosted-runners/images/custom/{image_definition_id}/versions/{version}`
(no valid automatic fixture). Nullable metadata is preserved without promising
support for every nullable request representation.

DigitalOcean's 76 diagnostics include
`DELETE /v2/account/keys/{ssh_key_identifier}` (parameter composition) and
`DELETE /v2/firewalls/{firewall_id}/rules` (body composition). They replace
historical false positives, rather than regress working request contracts.

Stripe's old blanket form-media blocker is gone. Its 568 remaining operations
expose 136 body-composition blockers, 20 nested URL-encoded form blockers, and
412 parameter serialization/composition blockers (some have multiple reasons).
Examples are `DELETE /v1/subscriptions/{subscription_exposed_id}`,
`POST /v1/account_links`, and `GET /v1/accounts`, respectively. The 26 supported
operations now pass fixtures and invocation, including empty URL-encoded bodies.

Box `POST /oauth2/revoke` now reaches fixture generation, where the supplied
example's undeclared `grant_type` field requires review. Its type is not inferred
from that example. The existing thumbnail fixture blocker also remains.

## Remaining scope and next decisions

Local references resolve relative to their containing file, with bounded
traversal and explicit missing/malformed/remote/cycle diagnostics. Initialized
clients bundle dependencies; direct source dependencies participate in generation
fingerprints. Remote references are not downloaded.

Request composition and broader nullable input support remain under **#12**.
The seven Kubernetes recursive-reference diagnostics are unchanged. The allOf
response fixtures and unused union components do not establish request-union
support. Decide that request representation deliberately before extending it.
Stripe's parameter serialization diagnostics also need a focused follow-up;
form transport alone does not clear them. OpenAPI 3.2, webhook-only documents,
and the four non-OpenAPI JSON Schema test arrays remain outside this pass.

The configuration review workflow for colliding operation names remains **#17**;
preserving base-function names safely does not complete that separate workflow.
The active 27-API / 69-group proving ground remains **328 renderable / 205 excluded
/ 15 blocked**, with no changed blocker keys or reasons. Its four AMOS schema
defects remain separate under **#16**. See the [active audit](../proving-ground/schema-gaps/README.md).

## Reproduce

Install this checkout, then run:

```r
source('dev/verify_schema_gaps.R')
verify_schema_gaps()
```

Each input runs in an isolated process with a 180-second timeout. The verifier
updates machine-readable records and [SUMMARY.md](SUMMARY.md); it preserves this
narrative report. [Document comparison](document-comparison.csv),
[all operation records](operations.csv), and [source URLs/hashes](sources.csv)
provide the complete evidence.
