# Issue #8: parameter serialization verification

Verified 2026-09-11 using the installed development package. The active 27 API
files and 69 groups retain their reviewed configuration, exclusions, names, and
client-owned helpers. The audit hashes all proving-ground files before and after
planning and makes no public API requests or generated-client writes.

| Disposition | After #14 | After #8 |
| --- | ---: | ---: |
| Renderable | 329 | 328 |
| Excluded | 205 | 205 |
| Blocked | 14 | 15 |

No operation became renderable. The seven binary query declarations require
source-contract review; accepting a string array would falsely imply file-upload
support. One previously renderable operation is now explicitly blocked:

| Service | Newly blocked operation key |
| --- | --- |
| alerts_library_controller | `POST /api/alerts/groups` |

Six existing blockers now report `Binary parameter requires source contract
review (#16); Unsupported nested parameter object` instead of `Unsupported
parameter type`:

| Service | Changed operation key |
| --- | --- |
| alerts_alerts_controller | `POST /api/alerts` |
| hazard_hazard_controller | `POST /api/hazard` |
| resolver_default | `POST /api/resolver/safety-flags` |
| standardizer_library_controller | `POST /api/stdizer/groups` |
| standardizer_stdizer_controller | `POST /api/stdizer` |
| toxprints_toxprints_controller | `POST /api/toxprints/calculate` |

Flat parameter objects are supported; nested objects have no defined deepObject
representation. These request-shaped query parameters need contract review before
choosing an encoding. Four composition blockers remain under #12. The same four
AMOS invalid-type schema defects remain separate under #16; none was repaired or
reclassified as a serialization limitation.

[changed-blockers.csv](changed-blockers.csv) and
[newly-blocked.csv](newly-blocked.csv) contain exact records. The independent
historical audit still labels binary declarations as capability gaps in
[operations.csv](operations.csv). The authoritative parser classifications in
[native-diagnostics.csv](native-diagnostics.csv) are seven `review_required`,
four `capability_gap`, and four `schema_defect`.

## Verification and reproduction

```r
source('dev/verify_parameter_serialization.R')
verify_parameter_serialization()
```

Install the checkout first. Offline acceptance tests do not need this corpus:

```r
source('tests/parameter-transport.R'); parameter_transport_acceptance()
source('tests/parameter-diagnostics.R'); parameter_diagnostics_acceptance()
source('tests/authentication.R'); authentication_acceptance()
```

The 56 parameter wire contracts reuse `tests/native-transport.R` and verify
parser metadata through generated wrappers and fixtures to actual localhost
requests. They cover query/path/header/cookie styles, Swagger collection formats,
percent encoding, Unicode, repeated keys, delimiter values, defaults, omission,
empty scalar values, and validation before transport. Empty containers and
ambiguous delimiter values are rejected explicitly. Authentication tests verify
query credentials preserve parameter encoding and ordinary cookies coexist with
credential cookies. A migration test preserves an old client-owned helper and
reports the missing helper argument.

Clean-source `R CMD check --no-manual` passed with zero errors, warnings, or notes,
including all 28 acceptance scripts and vignette rebuilds. A separate local Quarto
version-query warning followed the successful check.

The configuration vignette documents the supported matrix and helper upgrade.
Semantics follow [OpenAPI 3.0 parameters](https://spec.openapis.org/oas/v3.0.3.html#parameter-object),
[Swagger 2 parameters](https://spec.openapis.org/oas/v2.0.html#parameter-object), and
[RFC 6570](https://www.rfc-editor.org/rfc/rfc6570). Nested/composed parameter
schemas, `content`, and `allowReserved: true` remain explicitly unsupported.
Examples never establish schema types.

The additional user-supplied testing schemas are staged separately in
`specmill-testing/additional-schemas`, with a download manifest. They are not
registered in the active 27-API audit; their formats include JSON Schema test
arrays and OpenAPI 3.2 inputs outside the current supported versions.
