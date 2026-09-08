# Handoff: Generalize wrapmaint into apipak

**Generated**: 2026-09-08 14:26 -04:00
**Branch**: `docs/apipak-generalization-handoff`
**Status**: Ready for implementation under a subsequent goal command.
**Authority**: User-approved plan, cross-checked against the planning conversation.

## Goal

Rename wrapmaint to **apipak** and make it a standalone R API-client generation
and maintenance package. Complete a wholesale replacement of ComptoxR's reusable
development machinery with service YAML, necessary client callbacks, and thin
maintenance commands, while preserving its public behavior and HTTP runtime.

ComptoxR is the critical priority and first delivery gate. The non-chemical
catalogue proves generic reuse. The Natural Products API is an independent
real-world stress test and subsequent standalone client; its extra requirements
must not delay the ComptoxR milestone. Overall completion includes full coverage
of that API's frozen schema, not merely a representative subset.

The current task is document creation only. No package implementation, remote
creation, schema freezing, installation, or release has been performed here.

## Completed

- [x] Read the original generalization handoff and inspected both generation paths.
- [x] Inspected boosterpak's TOML configuration and reusable pack organization.
- [x] Inspected apipkgen's source, YAML examples, helper templates, and license.
- [x] Inspected the supplied Natural Products OpenAPI document over HTTP.
- [x] Audited ComptoxR's filter, example, documentation, and lifecycle behavior.
- [x] Resolved the product decisions listed below and obtained approval of the plan.

## Key Decisions and Conversation Cross-check

| Decision | Agreed result |
|---|---|
| Package name | **apipak**; renaming is step 0. |
| Primary target | Full ComptoxR maintenance migration, not a rename/filter-only milestone. |
| Configuration | YAML first; follow boosterpak's declarative organization, not its exact TOML format. |
| Service separation | A project file explicitly selects separate CTX, Chemi, and EPI YAML files; split Chemi further where policies differ. |
| Selection rules | Client-owned method allowlists and regex exclusions; GET/POST restrictions are not hardcoded into apipak. |
| Path matching | Original schema paths, before request-path rewriting; translate existing filters and prove operation-set parity. |
| Existing projects | Replace the current dev workflow without recreating the package or changing its public contracts. |
| New projects | Provide a small initialization command, then use the same maintenance workflow. |
| HTTP support | Generate helpers into new clients; generated clients do not require apipak at runtime. |
| ComptoxR runtime | Retain current HTTP helpers, authentication, batching/pagination behavior, and runtime hooks. |
| Removed output | Plan eligible removals; explicit apply removes only verified owned, unprotected output. Manual and lifecycle-protected files stay protected. |
| Documentation | Preserve example values/calls, parameter and return docs, exports, lifecycle badges, and existing tags. |
| Custom tags | `@apiStage` is preserved for ComptoxR; it is not mandatory metadata for every client. |
| Upstream deprecation | Report it for review; wrapper lifecycle becomes explicit policy. First capture existing effective badges so migration does not change them. |
| Reuse validation | ComptoxR plus the non-chemical catalogue, followed by Natural Products full-schema coverage. |
| Natural Products delivery | Separate maintained R package/repository with docs, generated helpers, and tests. |
| apipkgen reuse | Borrow useful design/code selectively with attribution; do not replace the stronger existing engine with its legacy generator. |

Implementation defaults from the approved plan: project file `apipak.yml`,
source remote `seanthimons/apipak`, and provisional second-client name
`naturalproductsR`. Only **apipak** was explicitly chosen by the user as a final
package name. The provisional client name and repository availability must be
checked before publication; they do not block ComptoxR work. Keep the current
local directory name during implementation to avoid path disruption.

## Current State

**Toolkit source**: `C:/Users/sxthi/Documents/wrapmaint`, implementation commit
`aae88f99f6bd355a06d3404fd100b86620609e83`, originally on `feat/schema-toolkit`.
Working tree was clean before this document. No Git remote is configured.

**ComptoxR reference**:
`C:/Users/sxthi/Documents/ComptoxR/.worktrees/workflow-production-gaps`, commit
`df4e708ce3f3ad5dae4db553a6c40aff97972ecf`, clean at inspection.
[PR 309](https://github.com/seanthimons/ComptoxR/pull/309) was still OPEN with that
head on 2026-09-08. Recheck before choosing an implementation base; do not lose
its production-policy work by starting from an older integration checkout.

**Working implementation**: local JSON schema parsing; a neutral R-list
generation interface; fixture selection; comparisons; hook validation; protected
file application; an installed compatibility engine used by ComptoxR.

**Not implemented**: a YAML project loader, full declarative maintenance workflow,
new-client initialization, or generated general-purpose HTTP helpers. The local
ComptoxR renderer and parameter modules retain substantial implementation.
No fresh claim of runtime breakage is made by this planning audit.

**Verification status**: historical acceptance results in the source handoff are
not fresh results. No package tests were rerun for this document-only task.

**Pinned legacy artifact**: wrapmaint 0.1.0, source `aae88f9`, attached to
[ComptoxR v2.0.0](https://github.com/seanthimons/ComptoxR/releases/download/v2.0.0/wrapmaint_0.1.0.tar.gz).
SHA-256: `a9e8ff83f1316b1e3059c63ab84e7aa01567bb7c2156259400bf791781408fe0`.
Never replace this archive. ComptoxR's development lock pins it with policy
`comptox-compatibility-1`.

## Files to Know

Paths below are relative to this checkout unless prefixed `ComptoxR/`; that
prefix means the reference worktree above, not an arbitrary installed package.

| File or directory | Role |
|---|---|
| `../ComptoxR/.worktrees/workflow-production-gaps/wrapmaint-generalization-handoff.md` | Original extraction evidence, warnings, and setup. |
| `R/generation.R`, `R/operations.R`, `R/endpoint_records.R` | Neutral generation, ownership, parsing, comparison, and legacy-table bridge. |
| `R/context.R`, `R/groups.R` | Compatibility rebinding and implicit context dependencies. |
| `R/fixtures.R`, `R/test_renderer.R`, `R/scaffold.R` | Fixture precedence, contract tests, lifecycle protection. |
| `tests/`, `inst/catalogue/` | Installed-package acceptance and non-chemical client. |
| `ComptoxR/dev/toolkit_adapter.R`, `ComptoxR/dev/stub_specs.R` | Staging/apply adapter, service selection, naming, helper policy. |
| `ComptoxR/dev/endpoint_eval/` | Mixed local implementation and toolkit shims; inspect definitions and every caller. |
| `ComptoxR/dev/test_generation/` | Client fixture policy, metadata, test rendering, token preflight, and toolkit shims. |
| `ComptoxR/dev/remove_experimental.R` | Parsed export/lifecycle/stage ownership rules. |
| `ComptoxR/inst/hook_config.yml` | Existing runtime hook configuration; do not confuse it with project configuration. |
| `ComptoxR/CONTRIBUTING.md`, `ComptoxR/dev/migration-evidence/` | Workflow and historical regression evidence. |

## Code Context and Intended Interface

Current callable API:

```r
spec <- list(files = '/absolute/path/openapi.json',
             helper = 'request_helper', policy_version = 'reviewed-1')
wrapmaint::generate_client('/existing/client/root', spec, 'plan')
```

Preserve existing function names and positional R-list calls under `apipak::`.
Add a named `config` input and explicit callback environment without creating a
second engine. The intended convenience call is not callable today:

```r
apipak::generate_client(root = '.', config = 'apipak.yml', mode = 'plan')
```

The default existing helper contract is `method`, `path`, `path_params`, `query`,
and `body`. ComptoxR's existing helpers have different contracts that must be
represented explicitly, not replaced during this migration.

Project configuration shape:

```yaml
config_version: 1
services:
  - apis/ctx.yml
  - apis/chemi.yml
  - apis/epi.yml
```

Each service specifies stable identity, local schema inputs, selection rules,
request settings/helper mapping, output naming, documentation/examples/fixtures,
and explicit operation overrides. Configuration file and schema paths resolve
against the explicit project root. Schemas are associated explicitly; a shared
host or URL substring must not choose a service's policy implicitly.

Keep configuration as data. For executable behavior, use ordinary R functions
resolved only in the supplied environment. Do not put arbitrary R source strings
in YAML or evaluate schema descriptions/examples. Retain client runtime hook
configuration; avoid two editable sources of truth for the same hook setting.

## Not Yet Done: Ordered Implementation

### Step 0: Baseline and rename

- [ ] Read current instructions, contribution docs, original handoff, and extraction
  plan. Recheck Git state and PR 309; create isolated implementation worktrees.
- [ ] Before renaming, freeze schema/policy hashes, selected operation identities,
  generated/protected files, signatures, exports, docs, hooks, and current results.
  Use current production output, not the historical pre-policy file counts.
- [ ] Rename metadata, namespace lookups, installer checks, docs, and tests to
  apipak. Preserve legacy ownership headers and interrupted-apply recovery.
  Do not rewrite historical evidence or immutable artifact references.
- [ ] Retain compatibility entry points until migrated callers no longer need
  them. Establish the toolkit's source remote and normal release workflow.
- [ ] Gate: renamed installed-package acceptance passes with equivalent output
  contracts and ownership. Exclude this handoff from built package artifacts when
  updating package build configuration.

### Phase 1: YAML and one operation inventory

- [ ] Implement one versioned YAML loader/validator feeding the existing R model.
  Reject unknown fields, invalid types/methods/regexes, duplicate IDs, unsafe
  paths, unresolved callbacks, and name/output collisions before writing.
- [ ] Migrate the full existing filter lists, preserving service scope and
  case-sensitive stringr regex behavior. A list means exclude if any pattern
  matches, not vectorized pairwise matching of paths and patterns.
- [ ] Match original schema paths; translate filters currently applied after
  stripping prefixes/path parameters. Prove equivalence on frozen schemas.
- [ ] Use stable service ID + method + original path as operation identity.
  Do not use an absolute checkout path as the durable identity. Reject conflicting
  duplicate operations within a service; preserve cross-service distinctions.
- [ ] Resolve inventory once for generation, comparison, tests, hook checks, and
  coverage. Track selected, excluded, unsupported, generated, and manual status
  explicitly, retaining diagnostic reasons and source provenance.
- [ ] Gate: identical selected ComptoxR operation identities, including GET/POST
  pairs and service-specific exclusions. No EPA policy is an engine default.

### Phase 2: Full ComptoxR maintenance replacement

- [ ] Audit each local definition/caller into reusable engine, declarative data,
  necessary callback, or replaced shim; include the large renderer and parameter
  modules, schema diffing, test generation, coverage, hook checks, and CI outputs.
- [ ] Move common implementation into apipak. Preserve public names, formals,
  defaults/order, helper-call shapes, request placement, batching/pagination, hook
  ordering/state/skip/result behavior, and multi-function file layouts.
- [ ] Keep chemistry resolution, credentials, transport, and runtime hooks local.
  Do not leave the old large renderer behind under a callback label or move
  chemistry branches wholesale into a supposedly generic engine.
- [ ] Provide new-package initialization and existing-project adoption. Existing
  projects are not recreated; existing dev commands become thin apipak calls.
- [ ] Return structured inventory, diagnostics, coverage, file actions, and
  manifest information. Thin scripts retain CLI exit codes and CI reporting.
- [ ] Delete only replaced implementation after updating every caller, workflow,
  documentation reference, and test. Preserve R-list API compatibility where
  feasible; intentional changes require documented migration evidence.
- [ ] Gate: ComptoxR's entire maintenance workflow uses apipak, not just filters.

### Phase 3: Documentation and reconciliation

- [ ] Preserve parameter/return docs, examples, exports, custom tags and rendered
  help. Match documentation to actual formals. `@apiStage` remains client-specific;
  retaining it does not impose ComptoxR's public/staging vocabulary on other APIs.
- [ ] Retain schema tags as metadata and support explicit documentation grouping
  overrides. Tags do not become implicit endpoint filters.
- [ ] Move chemistry-specific example values into ComptoxR YAML. Use reviewed
  overrides, schema examples/defaults/enums, then valid type fixtures. Distinguish
  missing from explicit null/false/zero; preserve scalar and one-element-array
  shapes. Invalid candidates require reviewed input rather than executable text.
- [ ] Preserve existing calls/values with explicit overrides where generic
  selection differs. Keep deterministic selection; keep documentation examples
  separate from independently authored request expectations. Live documentation
  examples remain non-executing in routine checks (current renderer uses dontrun).
- [ ] Support service lifecycle defaults and operation overrides. Capture current
  effective badges first: today's renderer forces deprecated for upstream
  deprecation. New upstream deprecation becomes a review diagnostic, not an
  automatic wrapper lifecycle change. Preserve existing deprecated badges.
- [ ] Preserve lifecycle protection: stable, maturing, superseded, deprecated,
  defunct, mixed, and unrecognized/untagged files must not become writable merely
  because headers or policy changed. Do not demote badges to permit regeneration.
- [ ] Plan all writes/protected conflicts/eligible removals. Explicit filters may
  remove only verified owned, unprotected output during apply. Unsupported or
  malformed inputs never authorize removals. Mixed files retain protected content.
- [ ] Render and validate all desired output before mutation. Preserve backups,
  rollback and interrupted-apply recovery; do not claim a cross-file transaction.
- [ ] Check fails on stale required output, blocking diagnostics, or protected
  conflicts preventing the requested result. It must not report success merely
  because an unsupported operation produced no desired file.
- [ ] Gate: read-only plan/check, deterministic regeneration, no-op second apply,
  documentation parity, and failures that preserve owned/manual output.

### Phase 4: ComptoxR delivery gate

- [ ] Migrate the non-chemical catalogue through the same public configuration
  interface; no hidden ComptoxR profile or engine edits for that client.
- [ ] Pass the verification below and document every intentional difference.
- [ ] Publish a new immutable apipak artifact. Verify the downloaded archive's
  checksum and install in an isolated library before updating ComptoxR's pin.
- [ ] Preserve rollback as previous toolkit pin plus matching generated output.
  Do not add an apipak runtime dependency to ComptoxR or automatically release
  ComptoxR for development-only changes. Follow its version/release workflow.
- [ ] Provide installation, full config reference, migration/rollback guidance,
  callback examples, schema support matrix, diagnostics, ownership, and a complete
  new-client walkthrough. Explain helper-call checks versus actual HTTP proof.

### Phase 5: Natural Products full-coverage stress test

- [ ] Freeze [the supplied schema](https://api.naturalproducts.net/latest/openapi.json)
  with retrieval source/date and checksum. It was inspected but not saved during
  planning; `/latest` may change before implementation.
- [ ] Create the standalone client repository/package (provisional name above).
  Generate client-owned httr2 helpers and documentation through the same workflow.
  The client must work without apipak installed or loaded.
- [ ] Support every operation in the frozen schema. The inspected schema uses
  OpenAPI 3.1, relative server `/latest`, scalar/nullable/alternative inputs, JSON
  and text/plain bodies, multipart uploads, and JSON/SVG responses. Handle observed
  schema quirks through documented configuration or generic support, not hidden
  chemistry-specific branches. Resolve the server against the recorded origin.
- [ ] Cover each operation with independent request expectations and successful
  return assertions. Use deterministic local HTTP tests for query/path encoding,
  null/array handling, uploads, body media, errors, and response decoding.
- [ ] Report live upstream failures separately from local contract failures. Do
  not equate generated files or mocked helper calls with upstream HTTP success.
  This plan does not authorize production writes, remote job submission, or live
  cassette recording merely to satisfy test counts.
- [ ] Gate: all frozen-schema operations supported and validated; no artificial
  exclusions to achieve full coverage. Preserve ComptoxR and catalogue gates.

## Pinch Points and Required Regression Checks

| Risk | Required evidence |
|---|---|
| Rename changes ownership or package lookup | Old headers remain recognized; installed apipak loads in isolation; legacy artifact unchanged. |
| Filters currently run at different stages | Compare exact selected operation sets per service, including regex near-matches and anchored routes. |
| Same method/path exists in multiple services | Separate naming overrides, comparison records, diagnostics, and output ownership. |
| Callback environments leak client state | Two-client isolation, explicit environment lookup, no source/load-time client execution. |
| Lifecycle is both documentation and protection | Effective badge parity plus protected/mixed-file apply and deletion checks. |
| Example value changes alter output or request shape | Deterministic fixtures, safe literals, false/zero/null, quotes/newlines, one-element arrays. |
| Failures look like successful empty generation | Structured unsupported diagnostics and failing check; no destructive reconciliation on incomplete input. |
| Migration silently changes runtime | Names/formals/exports, request placement, successful returns, hook order/state/skip behavior. |
| Generic pipeline retains hidden client machinery | Catalogue uses the same API; no chemistry defaults or giant local compatibility renderer. |
| Scale regresses | Rerun existing 2,000-operation case; report time/memory/environment and avoid per-operation reparsing. |

## Verification and Resume Instructions

1. Read this document and the original handoff fully. Check status, branches,
   remotes, PR 309, local instructions, and client contribution/release docs.
2. Start step 0 on dedicated implementation branches. Establish the current
   production baseline before changing package identity or generated files.
3. Run the installed-toolkit acceptance scripts after installation:

   ```sh
   Rscript tests/catalogue.R
   Rscript tests/boundaries.R
   Rscript tests/schema-versions.R
   Rscript tests/loading.R
   ```

   Also run R CMD check. Update package-name references as part of renaming.
4. In the appropriate ComptoxR checkout, install its reviewed pin for baseline
   checks, then repeat with the candidate toolkit during migration:

   ```r
   source('dev/install_toolkit.R')
   install_toolkit()
   devtools::test(
     filter = 'generate_tests_pipeline|stub_generation|diff_schemas|hooks'
   )
   ```

   ```sh
   Rscript dev/generate_stubs.R --check --rebuild=ct --rebuild=chemi --rebuild=epi
   Rscript dev/generate_tests.R --check
   Rscript dev/check_hook_config.R
   Rscript dev/check_public_api.R
   ```

   Expected: fresh generated output, passing targeted tests, valid hooks/public
   boundaries, and no working-tree changes. If baseline fails, inspect toolkit
   pin, formatter version, policy, and inputs before changing generated output.
5. Regenerate/render documentation in isolated output and compare semantic
   content, examples, badges, tags, signatures and exports. Account separately
   for intentional branding changes; no unrelated formatting churn.
6. Add focused adversarial tests for invalid configuration/regex, unsafe paths
   and symlinks, case-insensitive collisions, local/external/cyclic references,
   malformed body schemas, safe literal generation, recovery, and mixed files.
7. Verify generation from outside the client working directory; loading clients
   offline without apipak; no load-time requests, output generation, endpoint
   changes, or session-option mutations. A second apply must make no changes.
8. Record phase completion, commit IDs, exact validation, limitations, failed
   approaches, and next actions in this document. A passing ComptoxR milestone
   must be delivered before expanding for Natural Products. Do not mark the
   overall follow-up complete until the later full-coverage client also passes.

## Setup Required

R package dependencies and Air 0.9.0 are needed for the recorded ComptoxR workflow.
The original handoff records R 4.5.1 on this Windows host and `LC_ALL=C` as a
workaround for inherited unsupported `C.UTF-8`; verify the current environment.
Read UTF-8 documentation explicitly. New R validation scripts should be sourceable
from an interactive R session. Offline acceptance needs no production credentials.

## Failed Approaches

No generalization implementation has been attempted in this conversation.
Calling all remaining ComptoxR modules thin shims was an earlier characterization
error; the source handoff corrects it. Treat file deletion alone as insufficient.

apipkgen was inspected and rejected as a replacement engine: its Swagger loop
reads GET metadata/emits GET across methods, writers append output on repeated
runs, reference helpers use eval/parse, and the inspected tree has no test suite.
Its useful ideas are declarative configuration, new-package initialization, and
client-owned helper generation. If copying code, retain Scott Chamberlain's MIT
attribution. Source: <https://github.com/seanthimons/apipkgen>.

The original handoff records a pkgdown failure: `build_articles(articles = ...)`
rejected an unused argument; `build_article('articles/development-lifecycle')`
worked in that installed version. Verify available APIs before repeating it.

## Warnings and Deferred Work

- YAML configuration does not imply YAML schema support or full OpenAPI
  conformance. Retain the declared supported subset and extend for demonstrated
  requirements. Unsupported operations must remain visible.
- Defer hand-authored endpoint definitions, TOML, configuration inheritance,
  plugin registries, and additional HTTP backends. They were discussed, not
  selected as requirements for this migration.
- Do not claim tags/badges/example configuration, new-client initialization, or
  generalization as shipped merely because this handoff describes them.
- Keep original historical migration counts distinct from current production
  counts. Freeze actual current inventories; do not restore staging wrappers.
- Preserve users' unrelated `endpoint-audit.md` and harmonizer `CONTEXT.md`
  changes mentioned in the original handoff; do not reset/clean other checkouts.
- Future packaging should omit this development handoff from the source archive.
  No package build configuration is changed by this document-only task.
