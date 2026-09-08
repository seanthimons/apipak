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

YAML projects use the same generation function:

```r
apipak::generate_client('/absolute/client', config = 'apipak.yml', mode = 'plan')
```

```yaml
# apipak.yml
config_version: 1
package: exampleclient
services: [apis/catalogue.yml]
```

```yaml
# apis/catalogue.yml
id: catalogue
schemas:
  files: [schema/catalogue.json]
helper: request_helper
selection:
  methods: [GET, POST]
  exclude: ['^/internal/']
documentation: true
```

Paths resolve against the explicit client root. Service IDs distinguish identical
method/path pairs in different APIs. Exclusions use case-sensitive stringr
regexes against original schema paths, excluding a path if any pattern matches.
Schema `patterns` expand deterministic root-relative globs; schema `exclude`
matches basenames. Missing files or empty selectors fail. Unknown fields, invalid
types, duplicate IDs/names, unsafe paths and executable YAML tags fail.

Additional service fields are `names` (method/path to public name), `hooks`
(wrapper to ordered `pre_request` and `post_response` chains), `hook_callback`,
`policy_version`, `contracts`, `response_fixture`, and `prepare`. A preparation
callback is resolved only in the explicitly supplied `callbacks` environment;
it receives one operation and must preserve its identity. Configuration contains
data, never R source. YAML aliases are supported, explicit keys override merges,
and duplicate explicit keys are rejected.

Existing helper contracts use typed `defaults` and `operations` mappings:

```yaml
operations:
  GET /items/{id}:
    name: fetch_item
    parameters:
      path id: {name: identifier}
      query language: {default: en}
    extra_parameters:
      verbose: {type: logical, default: false}
    request:
      arguments:
        endpoint: {value: items}
        identifier: {from: [params, identifier]}
        language: {from: [params, language]}
    docs:
      title: Fetch an item
      lifecycle: experimental
      return: The client helper response.
      examples: [{identifier: example}]
```

Parameter overrides are keyed by original location and name. They support
`name`, `default`, `required`, `exclude`, and `description`. `parameter_order`
orders named public parameters before any remaining parameters. Extra parameters
are client inputs; they are sent only through explicit request bindings.
`request.arguments` replaces the default helper arguments. Each binding has
exactly `value` (literal data) or `from` (a path rooted at `params` or
`hook_state`). NULL, false, zero, and one-element lists remain distinct.

Pre-hooks replace only the public parameters they return. By default, a skipped
request returns immediately. `post_on_skip: true` also runs the post hook, and
`post_state: hook_state` passes the complete pre-hook state with its result
replaced. Both options require a pre-hook. A root-relative `hook_config` may
select existing runtime hook declarations instead of duplicating `hooks`;
unused declarations are returned separately in `unused_hooks`.

Documentation policy supports `title`, `description`, `parameters` (public-name
map), `return`, `lifecycle`, `tags`, and `examples` (a sequence of input maps).
Examples are rendered inside `dontrun`. Custom metadata tags use the client's
existing roxygen handlers; executable and structural built-in tags are rejected.
Schema prose and examples are never executable configuration. Lifecycle badges
come from validated policy, and protected badges continue to protect output.

For a new client, supply its metadata explicitly:

```r
apipak::initialize_client(
  '/absolute/newclient', '/absolute/schema.json',
  package = 'newclient', title = 'Example API Client',
  author = list(given = 'Your', family = 'Name', email = 'you@example.org'),
  license = 'MIT + file LICENSE', base_url = 'https://api.example.org'
)
apipak::generate_client('/absolute/newclient', config = 'apipak.yml', mode = 'apply')
```

Initialization refuses existing-file conflicts. It generates a client-owned
httr2 helper and declares httr2 in that client's DESCRIPTION. Existing package
metadata is retained; apipak is never a runtime dependency. The generated helper
makes one request, omits NULL query values while retaining false/zero, decodes
JSON without vector simplification, returns text/SVG as strings and binary as
raw bytes, and returns NULL for empty bodies. HTTP failures and malformed JSON
raise errors. The supported generated request body is JSON; multipart and
other unsupported schema constructs remain diagnostics.

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
without verified ownership, restricts paths to the target root, prepares output
and backups first, and verifies restoration after an apply error. Ownership
hashes live in `.apipak/manifest.json`; a header alone cannot authorize replacing
an existing file. Edited files and protected lifecycles prevent conflicting
writes. Explicit exclusions can remove verified owned output; protected removals
are reported as retained. Unsupported input never authorizes removal.

A recovery journal blocks subsequent application. Review with
`apipak::recover_client(root)` and restore with `apipak::recover_client(root, 'apply')`.
Both legacy and current journals are recognized; every destination and backup
is validated before restoration. Failed recovery retains its journal. There is
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
under its MIT license (Sean Thimons). Full ComptoxR migration and release/pin
adoption are still in progress; see the development handoff for completion gates.

References: [OpenAPI 3.0.3](https://spec.openapis.org/oas/v3.0.3.html),
[testthat namespace mocks](https://testthat.r-lib.org/reference/local_mocked_bindings.html),
[httr2 URL construction](https://httr2.r-lib.org/reference/req_url.html).
