# Full Petstore example

This example exercises all 19 operations in the downloaded live Petstore schema,
using specmill's existing configuration and client-extension mechanisms. It does
not change specmill's parser or claim that all endpoints generate automatically.

## What specmill handles

| Route through specmill | Operations | Meaning |
|---|---:|---|
| Native generation | 11 | Schema parameters and bodies generate directly |
| Explicit request mappings | 2 | Array query values and a header parameter use configured inputs and a client helper |
| Retained client implementations | 6 | Five JSON/XML/form alternatives and one binary upload are rejected by the native parser; reviewed client functions are retained |

The unconfigured plan has eight blocking diagnostics. The configured client has
19 public functions: 13 generated and six client-owned. Original limitations
remain in mapping_diagnostics and retained_diagnostics. No operations are omitted
from the combined three service selections. endpoint-coverage.csv records each
endpoint, public name, implementation category, and original diagnostic.

## Function groups

| Configuration | Functions |
|---|---|
| apis/pet.yml | pet_create, pet_update, pet_find_by_status, pet_find_by_tags, pet_get, pet_update_fields, pet_delete, pet_upload_image |
| apis/store.yml | store_inventory, store_order_create, store_order_get, store_order_delete |
| apis/user.yml | user_create, user_create_many, user_login, user_logout, user_get, user_update, user_delete |

New clients now get tag-based service YAML from `initialize_client()`, with
optional `naming = 'tag_prefix'`. This earlier example explicitly configures
its own names and groups. Each service
reads the same unchanged schema and selects its corresponding path prefix. The
package has one R namespace; prefixes make its functions easy to find together.

The project configuration lists the three service files:

```yaml
config_version: 1
package: petstoretrial
services: [apis/pet.yml, apis/store.yml, apis/user.yml]
```

Within apis/pet.yml, three independent settings control the public interface:

```yaml
names:
  GET /pet/{petId}: pet_get
defaults:
  file: R/pet.R
  docs:
    tags: {family: pet endpoints}
operations:
  GET /pet/{petId}:
    parameters:
      path petId: {name: pet_id}
```

The names map changes operationId getPetById to the R function pet_get. The
parameter override changes the R argument to pet_id while preserving petId on
the wire. defaults.file groups generated source in R/pet.R; docs.tags.family
groups related help topics. Operation keys always use the original HTTP method
and path, so public renaming does not change the endpoint.

To try a different generated name, edit the existing names entry to pet_fetch.
Do not add a second names key. From any working directory, use an absolute root:

```r
devtools::load_all('C:/Users/sxthi/Documents/wrapmaint')
root <- 'C:/Users/sxthi/Documents/wrapmaint/artifacts/petstore-full/petstoretrial'
specmill::generate_client(root, config = 'specmill.yml', mode = 'plan',
  artifacts = c('wrappers', 'documentation'))
specmill::generate_client(root, config = 'specmill.yml', mode = 'apply',
  artifacts = c('wrappers', 'documentation'))
devtools::load_all(root)
pet_fetch(7)
```

Generated definitions, exports, and help follow the configuration. Update the
independent test expectations when intentionally renaming the public API.
The current source includes the grouped-file rename fix found by this example;
released specmill 0.1.4 rejects that rename. The load_all call above loads the fix.
Client-owned help pages may link to the renamed function: check_petstore(root)
also refreshes those pages after you update the test expectations.
For implementation: existing entries, rename the client-owned function and its
roxygen documentation too: specmill verifies its formals and retains its code.

## Build, use, and inspect

From the specmill repository root:

```r
source('dev/build_petstore.R')
build_petstore(output = 'artifacts/petstore-full') # use a fresh output directory
```

The builder needs the installed specmill, desc, pkgbuild, rcmdcheck, roxygen2,
testthat, callr, and httpuv packages, plus specmill's dependencies. It saves both
the unconfigured and configured plans and the exact downloaded schema/checksum.

In a fresh R session, load the full installed build:

```r
trial <- 'C:/Users/sxthi/Documents/wrapmaint/artifacts/petstore-full'
library(petstoretrial, lib.loc = file.path(trial, 'library'))
pets <- pet_find_by_status('available')
pet_get(pets[[1]]$id)
store_inventory()
help('user_get', package = 'petstoretrial')
```

This package includes real write functions. The build's live smoke test only
retrieves pets and inventory. All 19 functions, including writes, are tested
against a temporary local HTTP server. No writes are sent to the public demo.

```r
testthat::test_local(file.path(trial, 'petstoretrial'))
native <- readRDS(file.path(trial, 'native-plan.rds'))
native$diagnostics
configured <- readRDS(file.path(trial, 'configured-plan.rds'))
configured$mapping_diagnostics
configured$retained_diagnostics
```

The tests independently specify wire expectations for every endpoint, including
PUT/POST/DELETE methods, path escaping, repeated array query values, headers,
JSON arrays, binary bytes, zero/false values, and HTTP errors. Package validation
builds and checks the source archive, then installs it in a fresh R process and
compares three live function results with direct requests. The public demo may
change between those reads; exact comparisons can fail when that happens.

After editing this example's configuration or client code, check_petstore(root)
regenerates, tests, rebuilds, and performs the same read-only live smoke check.
Restart R first if the installed package is already loaded on Windows.

## Boundaries of the demonstration

All endpoints are exposed, but full OpenAPI validation, alternate XML/form
representations, OAuth flows, and response-header return values are not supplied.
The six custom functions choose JSON or raw upload explicitly. The runtime adds
repeated query keys and explicit headers using httr2. Secrets are not stored in
configuration or fixtures; the header test uses a dummy value. Schema compliance
and the factual correctness of the public demo's records remain separate from
transport correctness.

Authoritative inputs: [live OpenAPI schema](https://petstore3.swagger.io/api/v3/openapi.json),
[httr2 query encoding](https://httr2.r-lib.org/reference/req_url.html), and
[httr2 body encoding](https://httr2.r-lib.org/reference/req_body.html).
