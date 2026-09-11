# Issue #14: JSON shape verification

Verified 2026-09-11 against the installed development package.

The reviewed 27 API files / 69 groups remain unchanged. The read-only audit
hashes every existing proving-ground file before and after planning.
No public API requests or generated-client writes were made.

| Disposition | Before | After |
| --- | ---: | ---: |
| Renderable | 293 | 329 |
| Excluded | 205 | 205 |
| Blocked | 50 | 14 |

All 36 standalone #14 blockers became renderable. The two shared blockers
below lost their open-object diagnostic and retain only parameter-type
limitations under #8. No newly exposed blocker reason or newly blocked key
was found. Remaining blockers: six parameter types (#8), four compositions
(#12), and the same four invalid AMOS types (#16). Source schemas, reviewed
exclusions, operation names, configuration, and client-owned helpers were
not modified. Renderability does not verify a remote service contract.

## Operations now renderable

| Service | Operation key |
| --- | --- |
| amos_forgetest | `POST /api/amos/all_similarities_by_dtxsid/` |
| amos_forgetest | `POST /api/amos/analytical_qc_batch_search` |
| amos_forgetest | `POST /api/amos/analytical_qc_keyset_pagination/{limit}` |
| amos_forgetest | `POST /api/amos/batch_search` |
| amos_forgetest | `POST /api/amos/dtxsids/` |
| amos_forgetest | `POST /api/amos/entropy_similarity/` |
| amos_forgetest | `POST /api/amos/fact_sheet_keyset_pagination/{limit}` |
| amos_forgetest | `POST /api/amos/mass_spectrum_similarity_search/` |
| amos_forgetest | `POST /api/amos/max_similarity_by_dtxsid/` |
| amos_forgetest | `POST /api/amos/method_keyset_pagination/{limit}` |
| amos_forgetest | `POST /api/amos/product_declaration_keyset_pagination/{limit}` |
| amos_forgetest | `POST /api/amos/safety_data_sheet_keyset_pagination/{limit}` |
| amos_forgetest | `POST /api/amos/spectral_entropy/` |
| arn_cats_forgetest | `POST /api/arn_cats` |
| descriptors_forgetest | `POST /api/descriptors` |
| mordred_descriptors_generator_forgetest | `POST /api/mordred` |
| pfas_atlas_forgetest | `POST /api/pfas_atlas` |
| pfas_cats_forgetest | `POST /api/pfas_cats` |
| rd_kit_descriptors_generator_forgetest | `POST /api/rdkit` |
| resolver_default | `POST /api/resolver/getpubchemlist` |
| resolver_default | `POST /api/resolver/getsimilaritylist` |
| resolver_default | `POST /api/resolver/getsimilaritymap` |
| resolver_default | `GET /api/resolver/ghs-list-count` |
| resolver_default | `POST /api/resolver/ghs-list-count` |
| resolver_default | `POST /api/resolver/lookup` |
| resolver_default | `POST /api/resolver/orderBySimilarity` |
| resolver_default | `POST /api/resolver/pubchem-section` |
| safety_safety_controller | `POST /api/safety/rqcodes` |
| search_search_controller | `POST /api/search` |
| standardizer_stdizer_controller | `POST /api/stdizer/chemicals` |
| standardizer_stdizer_controller | `POST /api/stdizer/records` |
| toxprints_toxprints_controller | `POST /api/toxprints/assays` |
| toxprints_toxprints_controller | `POST /api/toxprints/chemicals_categories` |
| toxprints_toxprints_controller | `POST /api/toxprints/toxprints_categories` |
| web_test_forgetest | `POST /api/webtest` |
| web_test_forgetest | `POST /api/webtest/predict` |

## Shared blockers now owned solely by #8

| Service | Operation key |
| --- | --- |
| hazard_hazard_controller | `POST /api/hazard` |
| resolver_default | `POST /api/resolver/safety-flags` |

Both now report `Unsupported parameter type`; before they also reported
`Unsupported free-form body object`. Full before/after records are in
[changed-blockers.csv](changed-blockers.csv). Remaining operation-level
evidence is in [operations.csv](operations.csv).

## Reproduce

```r
source('dev/verify_json_shapes.R')
verify_json_shapes()
```

Install the checkout first; the audit deliberately uses installed specmill.
Regression tests are independent of this external corpus and run offline:

```r
source('tests/native-transport.R'); native_transport_acceptance()
source('tests/nested-bodies.R'); nested_body_acceptance()
source('tests/diagnostics.R'); diagnostics_acceptance()
```

The localhost server verifies exact received JSON bytes for empty/populated
objects, typed maps, heterogeneous and nested arrays, null, omission, and
both normal and byte-limited serialization. A counting transport proves
invalid inputs fail before transport. Fixture checks use the same validator;
a 10,000-entry map checks the bulk path. Existing Petstore transport contracts
and the natural-products frozen-schema acceptance remain covered.

## Schema semantics and limits

The implementation follows [OpenAPI 3.0 Schema Objects](https://spec.openapis.org/oas/v3.0.3.html#schema-object),
[Swagger 2 body schemas](https://spec.openapis.org/oas/v2.0.html#schema-object),
and [Draft 4 array/object validation](https://json-schema.org/draft-04/draft-fge-json-schema-validation-00).
Examples supply fixtures only; they do not establish types. Composition,
recursive schemas, boolean schemas, and union/null type declarations remain
outside this slice. See the configuration guide for accepted R input shapes.
