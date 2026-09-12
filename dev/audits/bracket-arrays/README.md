# Explicit bracketed query arrays

This pass adds `query_array_style: brackets` for flat primitive query arrays.
It sends repeated encoded names such as `term%5B%5D=red&term%5B%5D=blue`.
The ordinary schema-driven behavior remains the default; an operation override
of `query_array_style: schema` restores it under an inherited bracket default.

The option reuses existing parameter metadata, scalar/array validation, URI
encoding, and the client-owned request helper interface. It adds no dependency,
API detection, source-schema rewrite, nested-object encoder, or union support.
Existing helpers must support `style = 'brackets'` in `parameter_serialization`.

The convention is documented by [Stripe's expansion examples](https://docs.stripe.com/api/expanding_objects).
It is deliberately opt-in: [OpenAPI's deepObject definition](https://spec.openapis.org/oas/v3.0.4.html#style-values)
covers objects, not arrays. URI bracket delimiters are percent-encoded.

The audit applies the option **only to the mirrored Stripe source**, through a
read-only parsing policy. All other sources use the default policy. Package
tests use generic temporary schemas and localhost, independently of this corpus.

To reproduce after installing the checkout:

```r
source('tests/bracket-transport.R'); bracket_transport_acceptance()
source('dev/verify_bracket_arrays.R'); verify_bracket_arrays()
```

The verifier compares every operation's stage/reason with the previous native
audit, requires all changes to be confined to Stripe, checks default Stripe
selection remains unchanged, and records exact changed keys and exposed blockers.
The underlying audit checks source hashes before and after.

## Verification (2026-09-11)

Stripe improves from 26 to **237 selected, rendered, fixture-generated, and
recording-helper-invoked operations**; 357 remain diagnosed. The default policy
still selects 26 and diagnoses 568. These are offline request-generation smoke
checks, not live Stripe or response-contract validation.

[changed-operations.csv](changed-operations.csv) records all **265 changed keys**:
211 gain smoke coverage and 54 expose a later parameter blocker. Useful gains
include `GET /v1/balance`, `GET /v1/balance_transactions/{id}`,
`GET /v1/customers/search`, `GET /v1/charges/{charge}`,
`GET /v1/invoices/search`, `GET /v1/invoices/{invoice}/lines`,
`GET /v1/reporting/report_types`, and
`GET /v1/reporting/report_runs/{report_run}`.

[exposed-blockers.csv](exposed-blockers.csv) retains every newly visible reason:

| Later blocker | Operations | Example key |
| --- | ---: | --- |
| Parameter composition | 50 | `GET /v1/balance_transactions` |
| Nested parameter object | 1 | `GET /v1/billing/credit_balance_summary` |
| Parameter array items | 2 | `GET /v1/credit_notes/preview` |
| Composition and nested object | 1 | `GET /v1/treasury/transactions` |

The other 32 source documents have unchanged operation stages and reasons.
The original 27-API proving ground remains **328 renderable, 205 excluded,
15 blocked**, including the same four AMOS schema defects under #16.
No source or proving-ground configuration changed.

Targeted acceptance passed: bracket transport, parameter transport (56 localhost
contracts), parameter diagnostics, form transport, configuration, mappings, and
mapped schemas. The bracket check covers exact encoded bytes (including spaces,
slashes, percent signs and brackets), required/invalid values failing before HTTP,
Swagger overrides, YAML inheritance, operation opt-out, and helper compatibility.
The existing native transport check also passed its 19 generated endpoints.
Package installation and `git diff --check` passed. No full package check was
rerun for this bounded change.
