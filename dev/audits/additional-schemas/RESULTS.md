# Additional schema corpus: 2026-09-11

Tested installed specmill from c50f5ea. All 33 primary downloads were exercised independently,
with all HTTP methods enabled and no proving-ground exclusions. Source hashes were unchanged.
The active 27-API configuration and its 328/205/15 baseline were not modified.

## Results

**1,524 operations passed parsing, rendering, fixture generation, and wrapper invocation
without an unresolved operation-level reference.** These are offline smoke passes, not
verified service contracts or complete response-schema support.

After conversion, parsing selected 2,186 operations and diagnosed 660. All selected wrappers rendered;
2,185 produced fixtures and 2,183 invoked a recording helper successfully. Of those, 659
DigitalOcean wrappers have unresolved operation references and are excluded from the 1,524.
Two GitHub documents aborted entirely, hiding 2,458 declared operations from operation-level
results. OpenAPI 3.2 (four operations), a webhook-only document, and four JSON Schema test
arrays were rejected at document level. The latter arrays are not OpenAPI inputs.

| Input | Declared | Selected | Diagnosed | Smoke passes, excluding unresolved operation refs | Document caveat |
| --- | ---: | ---: | ---: | ---: | --- |
| petstore.yaml (3.0 baseline) | 3 | 3 | 0 | 3 |  |
| petstore-expanded.yaml (3.0 expanded models) | 4 | 4 | 0 | 4 |  |
| api-with-examples.yaml (response examples) | 2 | 2 | 0 | 2 |  |
| callback-example.yaml (callbacks) | 1 | 1 | 0 | 1 |  |
| link-example.yaml (links) | 6 | 6 | 0 | 6 |  |
| uspto.yaml (real-world 3.0 (USPTO)) | 3 | 2 | 1 | 2 |  |
| webhook-example.yaml (3.1 webhooks) | NA | 0 | 0 | 0 | Missing paths: .docs-lib\additional-json\07.json |
| non-oauth-scopes.yaml (3.1 non-oauth scopes) | 1 | 1 | 0 | 1 |  |
| tictactoe.yaml (3.1 clean modeling) | 3 | 3 | 0 | 3 |  |
| 3.2-tags-example.yaml (3.2 (bleeding edge)) | 4 | 0 | 0 | 0 | Unsupported schema version in .docs-lib\additional-json\10.json |
| petstore.yaml (2.0 / Swagger) | 3 | 3 | 0 | 3 |  |
| uber.yaml (2.0 real-world (Uber)) | 5 | 5 | 0 | 5 |  |
| swagger.yaml (multi-file external $ref) | 4 | 2 | 2 | 2 |  |
| oneOf.yaml (bare oneOf) | 1 | 1 | 0 | 1 |  |
| anyOf.yaml (bare anyOf) | 1 | 1 | 0 | 1 |  |
| allOf.yaml (allOf inheritance) | 1 | 1 | 0 | 0 |  |
| allOf_composition.yaml (allOf composition) | 1 | 1 | 0 | 0 |  |
| composed-schemas.yaml (composed schemas mix) | 3 | 0 | 3 | 0 |  |
| oneOfDiscriminator.yaml (oneOf + discriminator + mapping) | 1 | 1 | 0 | 1 |  |
| oneOfArrayMapImport.yaml (oneOf inside array/map imports) | 2 | 2 | 0 | 2 |  |
| issue_9848.yaml (oneOf regression case) | 2 | 2 | 0 | 2 |  |
| oneOf.yaml (3.1 oneOf) | 1 | 1 | 0 | 1 |  |
| petstore-with-fake-endpoints-models-for-testing.yaml (the everything fixture) | 46 | 38 | 8 | 38 |  |
| oneOf.json (2020-12 oneOf edge cases) | NA | 0 | 0 | 0 | Not an OpenAPI document |
| anyOf.json (2020-12 anyOf edge cases) | NA | 0 | 0 | 0 | Not an OpenAPI document |
| ref.json (2020-12 $ref resolution) | NA | 0 | 0 | 0 | Not an OpenAPI document |
| unevaluatedProperties.json (unevaluatedProperties) | NA | 0 | 0 | 0 | Not an OpenAPI document |
| spec3.yaml (Stripe: deep oneOf, ~6MB) | 594 | 0 | 594 | 0 |  |
| api.github.com.yaml (GitHub 3.0: ~10MB, webhooks) | 1229 | 0 | 0 | 0 | i In index: 332. i With name: /orgs/{org}/{security_product}/{enablement}. Caused by error in `map()`: i In index: 1. Caused by error in `if (type == "object" && !is.null(json_schema[["properties"]])) ...`: ! missing value where TRUE/FALSE needed |
| api.github.com.json (GitHub 3.1: ~13MB) | 1229 | 0 | 0 | 0 | i In index: 7. i With name: /app. Caused by error in `map()`: i In index: 1. Caused by error in `if (schema_type == "array") ...`: ! the condition has length > 1 |
| swagger.json (Kubernetes: 2.0, x-k8s-* extensions) | 1202 | 1195 | 7 | 1195 |  |
| DigitalOcean-public.v2.yaml (DigitalOcean: bundled, clean-ish) | 659 | 659 | 0 | 0 | Unresolved operation refs: all apparent passes uncovered |
| openapi.json (Box: multipart, oauth2) | 297 | 252 | 45 | 251 |  |

## Actionable findings

1. **YAML ingestion:** all 26 YAML sources fail the JSON-only entry point. The table uses
   temporary JSON conversions with installed ruamel.yaml in YAML 1.2 mode. No bundling,
   schema repairs, example-derived types, name overrides, or API requests were applied.
2. **DigitalOcean is a false positive:** all 659 operations contain `$ref` to a local
   operation file. Those references are ignored, producing wrappers with no referenced
   inputs. Example: `GET /v2/1-clicks` -> `resources/1-clicks/oneClicks_list.yml`.
   These unbundled inputs require preprocessing or an explicit diagnostic; their smoke
   success must not be reported as supported operation contracts.
3. **Whole-document GitHub failures:** the 3.0 description aborts at
   `POST /orgs/{org}/{security_product}/{enablement}` with a missing logical value;
   the 3.1 description aborts at `/app` with a length-greater-than-one type condition.
   Exact native errors are retained in schemas.csv. No partial results survive.
4. **Base-function name collision:** both allOf examples use operationId `list` for
   `GET /person/display/{personId}`. The generated `list <- function(...)` calls bare
   `list(...)` internally, recursively invoking itself. Reproduced with a helper that
   explicitly calls `base::list`, confirming the generated wrapper is responsible.
5. **Fixture gap:** Box `GET /files/{file_id}/thumbnail.{extension}` renders but fixture
   generation fails. Integer height/width parameters require a minimum of 32; the
   source supplies parameter-level examples. A reviewed override is requested.
6. **Media and schema gaps:** 615 body-media diagnostics (594 Stripe operations), 34
   body-composition diagnostics, seven recursive-reference diagnostics (Kubernetes),
   two external-reference diagnostics, one invalid-type diagnostic, and one unsupported
   parameter-array-items diagnostic. Exact operation keys and reasons are in operations.csv.

Passing oneOf/discriminator examples does not establish composition support: many put
the complicated schemas in responses or unused components. Callback/link examples only
exercise their ordinary path operations; callback execution and link traversal are untested.
The four AMOS defects belong to the existing corpus and remain separate under #16.

## Reproduce

```powershell
python dev/prepare_testing_specs.py C:/Users/sxthi/Documents/specmill-testing/additional-schemas .docs-lib/additional-json
```

```r
source('dev/audit_testing_specs.R')
audit_testing_specs()
```

Each schema runs in an isolated R process with a 180-second timeout. Generated wrappers
execute against a recording helper, so this run does not test HTTP encoding, real
authentication, remote responses, or client-package initialization. The existing #8
localhost transport suite covers its supported encodings separately. No package runtime
code was changed here; the audit itself checks count consistency and source preservation.

[Schema results](schemas.csv), [operation results](operations.csv),
[unresolved operation references](coverage-caveats.csv), [source URLs and hashes](sources.csv).
