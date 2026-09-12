# GET-body source-contract review

Reviewed 2026-09-12 for #16. All ten historical declarations remain unresolved.
No service operation was invoked. Exact snapshot SHA-256 hashes and operation
pointers are recorded in [operations.csv](operations.csv); append `/requestBody`
to each pointer for the declaration reviewed here.

| API | GET path | Declared body |
| --- | --- | --- |
| chet | `/admin/errorreport` | Optional JSON open object |
| chet | `/admin/login` | Optional JSON open object |
| chet | `/admin/register` | Optional JSON open object |
| chet | `/admin/resolve` | Optional JSON open object |
| chet | `/auth/login` | Optional form-urlencoded open object |
| chet | `/auth/register` | Optional form-urlencoded open object |
| chet | `/auth/report` | Optional form-urlencoded open object |
| chet | `/chemicals/chemdelete` | Optional JSON open object |
| chet | `/chemicals/chemical_DL` | Optional JSON open object |
| resolver | `/api/resolver/ghs-list-count` | JSON object with values that are arrays of arrays of strings; required omitted |

The [EPA CheT guide](https://www.epa.gov/comptox-tools/chemical-transformations-database-chet-user-guide)
documents a browser interface, including administrative tools and chemical-list
exports. It does not establish the HTTP methods or body encodings of these nine
routes. Names such as `login`, `chemdelete`, and `chemical_DL` do not establish
safe request semantics or justify converting GET to POST.

The adjacent ComptoxR `apis/chemi-resolver.yml` maps the resolver GET to a
generated client with empty inputs and separately maps a POST at the same path.
That is downstream configuration, not controller evidence: it cannot establish
that dropping the GET body is correct or that callers should use POST instead.
No service-owned controller or independently documented request was found in
the scoped local and public-source review.

The [OpenAPI 3.0 Operation Object](https://spec.openapis.org/oas/v3.0.3.html#operation-object)
limits requestBody support to methods with defined body semantics. This is a
standards constraint, not evidence of what these particular services accept.
These documents must not be repaired by guessing a verb, moving inputs to query
parameters, or treating an HTTP 200 as acceptance of the body.

For every row, the missing evidence is a service-owned controller signature or
published request example specifying method, media type, accepted fields,
requiredness, and whether the body is consumed. The intended wire shape remains
unknown. Route any verified parameter correction to #8 and any new body encoding
to #9, with a minimal offline transport assertion using #7 infrastructure.

Current parsing can accept these declarations after the JSON/form work. That is
not source-contract acceptance. The ledger retains an explicit review diagnostic
even where the parser reports `selected`. No source override is justified by
the evidence gathered here.
