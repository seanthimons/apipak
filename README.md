# apipak

Development-only API wrapper maintenance tools, version 0.1.0.
Install this package for generation and checks. Generated clients retain their
own HTTP helper, credentials, base URL, hook callback and response parser.
They do not import this package. Installation and loading do not generate files,
attach client packages, make requests or change options.

```r
spec <- list(files = '/absolute/path/schema.json', helper = 'request_helper',
  policy_version = 'reviewed-1')
apipak::generate_client('/absolute/client', spec, 'plan')
apipak::generate_client('/absolute/client', spec, 'apply')
```

The default helper contract is `method`, `path`, `path_params`, `query`, `body`.
The helper owns transport and serialization. A parameter named `page` causes
one helper call. Optional `hooks` declare ordered `pre_request` and
`post_response` names. `hook_callback` names the client function that executes
them. Pre-hook state contains `params`, and may return `skip_request`/`result`.
Post-hook state contains `result` and `params`, and returns the final value.

The neutral parser supports OpenAPI 3.0/3.1 and Swagger 2.0 local documents,
scalar path/query parameters, local references, JSON objects with scalar
properties, and arrays of scalars or such objects. Both clients use the extracted
endpoint-table parser. Neutral records add validated source metadata, including
source identity/hash, version, serialization and default presence. Unsupported media,
array/object parameters, external/cyclic references and composed/free-form bodies
produce operation diagnostics. It is not a full OpenAPI validator. Type, enum,
numeric and string constraints are checked when choosing fixture values;
unsupported input needs an explicit reviewed fixture or manual implementation.
JSON object bodies are named R lists. JSON arrays are R lists of scalar values
or named object lists; use lists so a one-element array retains its array shape.
Required fields must be present. Scalar fixture selection checks type, enum,
minimum/maximum, minLength/maxLength and pattern. Runtime helpers retain
responsibility for complete value validation and serialization.

`operation_fixtures()` uses override, example, default, enum, then type fixtures.
It fails when the candidate does not meet supported constraints. It never
evaluates a schema example as R code. `compare_operations()` reports required
additions/removals and review/unknown changes. It does not prove response or
serialization compatibility.

`bind_tools(group, environment)` installs the extracted compatibility functions
into an explicit client context. The client supplies its schema selection,
method allowlist, body classification, renderer, fixtures and reporting policy.
This API preserves the older endpoint-table contract. Its legacy diff counts
and helper-call tests are regression checks, not general compatibility proof.
The neutral renderer does not use this specialized policy.

`apply_files()` parses all R output before any mutation. It protects files
without the exact generated header (including legacy headers explicitly
supplied by clients), restricts paths to the target root, prepares output and
backups first, and restores backups after an apply error. A recovery journal
is retained if applying output fails. A process termination during apply can
leave that journal; restore its listed backups before another run. There is
no cross-file filesystem transaction. Client generation renders in isolation
before this short apply step. Unsupported operations do not remove files.

Run `Rscript tests/catalogue.R`, `Rscript tests/boundaries.R`,
`Rscript tests/schema-versions.R` and `Rscript tests/loading.R` after installation.
The catalogue has independently written request expectations and generated
testthat contracts from those fixed records. It checks successful
completion, rejects four intentional faults, and checks an httr2 request's URL
and JSON placement. The helper does not send that request. Generated helper-call
tests alone do not prove HTTP transport or upstream response conformance.

The extracted compatibility code originates from ComptoxR commit `8f055b8`
under its MIT license (Sean Thimons). Toolkit branding/public publication remains
separate from the client migration.

References: [OpenAPI 3.0.3](https://spec.openapis.org/oas/v3.0.3.html),
[testthat namespace mocks](https://testthat.r-lib.org/reference/local_mocked_bindings.html),
[httr2 URL construction](https://httr2.r-lib.org/reference/req_url.html).
