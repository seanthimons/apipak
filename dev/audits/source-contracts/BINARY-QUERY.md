# Issue #16: binary query declarations

Reviewed 2026-09-12. This records every historical binary-query declaration in
the proving-ground source snapshot, plus the subsequently exposed
`POST /api/alerts/groups` declaration. It makes no service requests and does
not change a schema, fixture, configuration, or helper.

## Evidence and rule

The download catalog records `https://hcd.rtpnc.epa.gov/` as the service origin
in `C:/Users/sxthi/Documents/specmill-testing/specmill-apis.yml`. Its hashes
identify the original downloaded bytes. This audit instead cites the hashes of
the normalized proving-ground snapshots used to produce the diagnostics. Current upstream availability and byte identity were not established.

For every row, the source explicitly places `files[]` **in `query`** as an
array of `string` with `format: binary`. Some rows also declare a JSON
`requestBody`, while others declare no body media type. Neither the field name
nor an operation ID containing `Multipart` establishes a different wire
encoding. Under the [OpenAPI Parameter Object](https://spec.openapis.org/oas/v3.1.0.html#parameter-object), `in` names the parameter location; a body media
type must be declared through a [Request Body Object](https://spec.openapis.org/oas/v3.1.0.html#request-body-object).

No public implementation or service-owner documentation was found that resolves
these contradictions. The source endpoint could not be used to obtain a current
document during this review. Therefore **all declarations remain review-required**:
do not rewrite them as multipart, JSON, or string query parameters.

## Historical declarations (11)

| Operation | Policy status | Declared shape | Authoritative intended shape | Disposition |
| --- | --- | --- | --- | --- |
| `POST /api/alerts` | active | required `query files[]`; required `query request: AlertFilesRequest`; required JSON body `AlertRequest` | Not established; declaration conflicts | retain review diagnostic |
| `POST /api/alerts/groups/{id}/add` | excluded (`add`) | required path `id`; required `query files[]`; optional `query request: GroupAddRequest`; no body | Not established | retain excluded record |
| `POST /api/hazard` | active | required `query files[]`; required `query request: HazardMultipartRequest`; required JSON body `HazardRequest` | Not established; declaration conflicts | retain review diagnostic |
| `POST /api/resolver/casharvest` | excluded | required `query files[]`; required `query request: FilesUploadRequest`; no body | Not established | retain excluded record |
| `POST /api/resolver/safety-flags` | active | required `query files[]`; required `query request: FilesUploadRequest`; required JSON body `Chemical[]` | Not established; declaration conflicts | retain review diagnostic |
| `POST /api/resolver/universalharvest` | excluded | optional `query files[]`; required `query request: UniversalHarvestRequest`; no body | Not established | retain excluded record |
| `POST /api/services/files` | excluded (`file`) | required `query files[]`; required `query request: FilesUploadRequest`; no body | Not established | retain excluded record |
| `POST /api/stdizer/groups` | active | required `query files[]`; required `query request: LibraryGroupUploadRequest`; required JSON body `LibraryGroupInfo` | Not established; declaration conflicts | retain review diagnostic |
| `POST /api/stdizer/groups/{id}/add` | excluded (`add`) | required path `id`; required `query files[]`; optional `query request: GroupAddRequest`; no body | Not established | retain excluded record |
| `POST /api/stdizer` | active | required `query files[]`; required `query request: StdizerRequest`; no body | Not established; `stdizeRequestPostMultipart` is only a name | retain review diagnostic |
| `POST /api/toxprints/calculate` | active | required `query files[]`; required `query request: ToxprintsFilesRequest`; required JSON body `CalculateRequest` | Not established; declaration conflicts | retain review diagnostic |

## Later exposure and active-set reconciliation

`POST /api/alerts/groups` is not one of the eleven historical operation records
in [`operations.csv`](../proving-ground/operations.csv), but it is the seventh
current active review case in
[`composition/active/operations.csv`](../composition/active/operations.csv).
It declares required `query files[]` and required JSON body `LibraryGroup`,
with no source evidence for an alternative transport. It has the same
disposition: retain its review diagnostic.

Thus the historical set is 11 (six active and five excluded), while the current
active set is seven after the later `alerts/groups` exposure. The union is 12;
the added row does not resolve, replace, or legitimize the excluded declarations.

## Audited source locations and hashes

| Service document | Normalized audit snapshot | SHA-256 used by audit |
| --- | --- | --- |
| alerts | `specmill-testing/schema/alerts.json` | `cecbdcd127341313fdc861107caaaf1a5b199c0926266ed698b1d38f9579a708` |
| hazard | `specmill-testing/schema/hazard.json` | `79c63e98176a2e980e85b41e1186cb69b1b4839990f1b35b48f03f1dffd1ae8e` |
| resolver | `specmill-testing/schema/resolver.json` | `dc1e9c3cef8a55250ac4dd28d4a0b48c0192a11535472e7c8e6eb550f9023694` |
| services | `specmill-testing/schema/services.json` | `48a117f62a336a5fa5f3f5de72fa2332ae48f63cd7612a2163da84aa48e2edcd` |
| standardizer | `specmill-testing/schema/standardizer.json` | `8c8a37d7d459a6e4d336d6a4f12ca27a8613bc2e3d8f1f5d18129e8a8e0d0916` |
| toxprints | `specmill-testing/schema/toxprints.json` | `3043998018f55ee4e79cf241b8b57b2d5b5344c35d3dc0b3753e03827ed54866` |

[`proving-ground/schemas.csv`](../proving-ground/schemas.csv) is the hash
ledger. [`proving-ground/operations.csv`](../proving-ground/operations.csv)
contains the historical diagnostic and pointer for each of the eleven rows;
[`composition/active/operations.csv`](../composition/active/operations.csv)
contains current active status.

The [review ledger](operations.csv) records the actual snapshot hashes and diagnostic pointers for all twelve binary-query cases.
