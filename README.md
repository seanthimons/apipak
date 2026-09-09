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

`read_operations()` also returns `unsupported_operations` for structurally valid
input metadata outside the default serializer's subset. A complete client
`inputs` and `request` mapping can use that metadata. Generation reports these
operations as `client-mapped`, retaining the original reasons in the inventory
and `mapping_diagnostics`; it does not claim native serialization support.
Malformed metadata and broken references block automatic generation even with mappings.
An explicit `implementation: existing` retains a named implementation, checks
its declared public inputs against the actual formals, and reports any schema
limitations in `retained_diagnostics`. This does not regenerate that source.
`file: R/name.R` preserves grouped layouts; generation rejects a group containing
a retained implementation, undeclared function, or other top-level code.

The default helper contract is `method`, `path`, `path_params`, `query`, `body`.
The helper owns transport and serialization. A parameter named `page` causes
one helper call. Optional `hooks` declare ordered `pre_request` and
`post_response` names. `hook_callback` names the client function that executes
them. Pre-hook state contains `params`, and may return `skip_request`/`result`.
Post-hook state contains `result` and `params`, and returns the final value.

An existing client can declare its complete public `inputs` map instead of
schema parameter overrides. Input records contain `required`, `default`, `type`
and `description`; required inputs have no R default. This preserves ordinary R
argument semantics, including explicitly supplied NULL, while the client's
existing helper/hooks validate values. A complete input map requires an explicit
request mapping. Original schema parameters/body remain in the operation's
`schema_parameters` and `schema_body` metadata.

Grouped request bindings use `object` (named list), `compact_object` (named list
with NULL entries omitted, returning `list()` when empty), `array` (an unnamed list, retaining NULL positions),
or `vector` (named `c()` values). Their entries are bindings too. A `callback`
binding names an ordinary function in the explicit
callback environment. It receives the operation and returns either literal data
or an R language object to emit; strings remain quoted literals. This supports
existing runtime computations without putting R source in YAML. For example:

```r
callbacks <- new.env(parent = emptyenv())
callbacks$batch_limit <- function(operation) {
  quote(as.numeric(Sys.getenv('batch_limit', '1000')))
}
apipak::generate_client(root, config = 'apipak.yml', callbacks = callbacks)
```

Use `{callback: batch_limit}` for the corresponding helper argument. YAML
generation validates required and unknown helper arguments against the client's
parsed function definitions before application.

For fixed expectations with R classes, a service can name
`contracts_file: tests/testthat/fixtures/contracts.rds`. This is a named list of
operation names, each with `inputs`, `calls` and `result`. Each call records
`helper`, `arguments` and `response`. Generated tests assert the complete ordered
call sequence and successful result; the fixture remains independent of generated
wrapper parsing. Ordinary YAML contracts remain supported. RDS fixtures preserve
tibbles, integer vectors, matrices and other data without executable YAML tags.
Optional contract `environment` values are scoped with `withr::local_envvar()`;
clients using that field need withr in their test dependencies. Fixed sequence
tests use `test-contract-<operation>.R`, keeping existing manual suites separate.

At project level, `formatter: {name: air, version: '0.9.0'}` requires that exact
installed version and formats the staged output in one subprocess. Optional
`callback_files: [dev/callbacks.R]` records source dependencies without executing
them; callers still supply the explicit callback environment.

The neutral parser supports OpenAPI 3.0/3.1 and Swagger 2.0 local documents,
scalar path/query parameters, local references, JSON scalar payloads, nested
objects with declared properties, and nested arrays. Both clients use the extracted
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

`inspect_client(root)` reports selected operation implementation and fixed-contract
file coverage from the same YAML inputs. Unsupported selections stay in the
denominator; manual exports are listed separately. File coverage does not claim
that tests passed. `script_root()` locates a thin maintenance command when run or
sourced from another working directory.
`check_public_boundary()` checks client-supplied public host, artifact and export
policy, including untracked source files. `check_client_hooks()` parses runtime
definitions once and checks the supplied client hook registry without loading
the client package.

`generation_command()` preserves wrapper/test command modes and GitHub output
names. Its default applies changes; `generate_client()` remains check-by-default.
The `artifacts` argument limits reconciliation to wrappers, tests or documentation.
`--force` never bypasses verified ownership. Missing fixed contracts block test
generation and report an explicit gap count.

`schema_diff()` uses method/path identities and explicit file/operation selection.
It compares canonical operation data and reachable local references, including
recursive response shapes. Changed contracts require review and enter the
breaking-change report lane conservatively; malformed input stops comparison.
These reports do not claim runtime or upstream compatibility.

`coverage_report()` and `test_gap_report()` take client YAML report policy and
default to read-only plans. Apply writes the existing badge/baseline or gap-report
fields and GitHub outputs. Coverage groups must partition configured services.
Manual request wrappers retain their tests outside the schema denominator; fixed
contract declarations and files are checked separately from test execution.

The `readiness` compatibility group keeps the existing versioned audit report
and sourced helper names. Bind it into an explicit environment with
`asNamespace('apipak')` as its parent, then supply `audit_policy` using its
`read_audit_policy()` reader. Credential names, issue metadata, badge/document
paths and test-tier descriptions belong in the client's YAML policy. Auditing
is read-only unless a report output path is explicitly requested.

`apply_files()` parses all R output before any mutation. It protects files
without verified ownership, restricts paths to the target root, prepares output
and backups first, and verifies restoration after an apply error. Ownership
hashes live in `.apipak/manifest.json`; a header alone cannot authorize replacing
an existing file. Edited files and protected lifecycles prevent conflicting
writes. Explicit exclusions can remove verified owned output; protected removals
are reported as retained. Unsupported input never authorizes removal.

After reviewing a legacy file, pass `adopt = list('R/example.R' = '<sha256>')`
to `generate_client()`. Hash UTF-8 text with LF line endings and no final newline.
Every supplied hash must still match; adoption cannot override lifecycle or
mixed-file protection. The manifest records source, configuration and fixture
hashes plus callback definitions. Unchanged reviewed files can be adopted without
rewriting them. Documentation ownership follows its source files.

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
