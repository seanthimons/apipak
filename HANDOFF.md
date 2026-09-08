# Handoff: Generalize wrapmaint into apipak

**Generated**: 2026-09-08 14:26 -04:00
**Hardened**: 2026-09-08, with source-level audit and implementation rules below.
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

The current task is handoff preparation and offline audit only. No package implementation, remote
creation, schema freezing, installation, or release has been performed here.

## Completed

- [x] Read the original generalization handoff and inspected both generation paths.
- [x] Inspected boosterpak's TOML configuration and reusable pack organization.
- [x] Inspected apipkgen's source, YAML examples, helper templates, and license.
- [x] Inspected the supplied Natural Products OpenAPI document over HTTP.
- [x] Audited ComptoxR's filter, example, documentation, and lifecycle behavior.
- [x] Resolved the product decisions listed below and obtained approval of the plan.
- [x] Reproduced six current implementation gaps with offline, sourceable probes.
  Added concrete rules to prevent those gaps from surviving the migration.

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
[PR 309](https://github.com/seanthimons/ComptoxR/pull/309) merged on
2026-09-08 at 18:53:37 UTC as `4fd720b97fb2f7f2abf131925e9270b0c11b057a`,
also the observed `main` head. The reference worktree still has the pre-merge
head above. Recheck before choosing an implementation base; do not lose
its production-policy work by starting from an older integration checkout.

**Working implementation**: local JSON schema parsing; a neutral R-list
generation interface; fixture selection; comparisons; hook validation; protected
file application; an installed compatibility engine used by ComptoxR.

**Not implemented**: a YAML project loader, full declarative maintenance workflow,
new-client initialization, or generated general-purpose HTTP helpers. The local
ComptoxR renderer and parameter modules retain substantial implementation.
No fresh claim of runtime breakage is made by this planning audit.

**Verification status**: historical acceptance results in the source handoff are
not fresh results. No full package suites were rerun. Six fresh offline audit
probes were run against the current source, using installed wrapmaint 0.1.0 for
its namespace dependencies; all six expose unmet target contracts. These are
diagnostic findings, not passing implementation acceptance.

**Question 1 resolved for planning (2026-09-08)**: the user believes the current
production baseline passes. Proceed on that working assumption; this is not a
newly verified test result. Before implementation changes, run the baseline
checks below against a revision containing PR 309, using the reviewed toolkit
pin and Air 0.9.0. Record failures as pre-existing or environmental before
assessing migration regressions. The implementer owns this verification; it
does not require another design discussion or user confirmation.

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
| `evidence/handoff-audit.R` | Sourceable reproductions of six pre-migration gaps; convert these cases into acceptance tests while implementing. |
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
- [ ] Snapshot the Natural Products schema as a reference input early, recording
  origin and checksum, so its later full-coverage target does not move. This is
  input capture only; do not start its feature work before the ComptoxR gate.
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

- [ ] Use the early frozen [supplied schema](https://api.naturalproducts.net/latest/openapi.json)
  with retrieval source/date and checksum. It was inspected but not saved during
  planning; `/latest` may change before implementation. Later refreshes are
  separate changes, not moving acceptance criteria.
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

## Hardened Implementation Rules

These rules resolve technical ambiguities in the approved plan. They do not add
another product milestone or permit unrelated runtime changes. Apply them while
completing the phases above, not as a separate framework-building exercise.

### Fresh audit evidence

Run `Rscript evidence/handoff-audit.R`, or interactively:

```r
source('evidence/handoff-audit.R')
handoff_audit('.')
```

The script reads current source, uses the installed legacy namespace for shared
dependencies, and writes only in a newly created, verified temporary directory.
It is a pre-migration diagnostic, not the future acceptance runner. Convert these
cases into positive regression tests as the affected functions are migrated.

| Target contract | Observed before migration |
|---|---|
| Cross-service comparisons retain all operations | A change to the second service's `GET /items` produces zero changes because comparison keys omit service identity. |
| Wrappers cannot overwrite their helpers | Naming a generated wrapper `request_helper` causes an unused-arguments error when it calls itself. |
| Final hook validation checks selected wrapper existence | A configured hook for an absent wrapper returns `valid = TRUE`. |
| Explicit-null fixture overrides retain their meaning | `override = NULL` selects the schema example instead. |
| A generated header does not discard local edits | An edited header-bearing file is planned for replacement without a previous-content check. |
| An unfinished apply blocks another apply | A recovery journal is ignored and the subsequent apply proceeds. |

Further source inspection found swallowed errors in ComptoxR's generated tests,
R-expression strings in existing hook configuration, and different skip-request
semantics between its request templates and the neutral renderer. These are
specific migration requirements, not claims that every existing wrapper is broken.

### 1. Normalize without losing ComptoxR capabilities

Do not funnel ComptoxR through the current strict neutral reader unchanged: it
rejects body shapes and media before a renderer/callback can handle them. Build
the raw operation index first, apply selection, resolve schema metadata and
declared client adaptations, then validate support for the chosen request
mapping. Retain one authoritative inventory; legacy endpoint tables may be
temporary derived views, not a second source of identity or parameter truth.

Keep original method/path/source, upstream parameter identity `(location, name)`,
public formal names/defaults, and helper argument mappings separate. A hook may
supply an upstream required field that is not a required public formal. Preserve
that distinction, including `hook_missing_params`. Do not round-trip rich
metadata through comma-separated parameter-name strings.

New transport fields such as media type or upload metadata must flow only to
helpers whose declared mapping accepts them. Do not add arguments to existing
ComptoxR helper calls merely because the new default transport supports them.

One logical service ID represents one request namespace. Different Chemi APIs
sharing a route need separate service IDs even if they share filter settings.
Duplicate operations within a service may be coalesced only if their normalized
contracts agree; conflicts fail with both source locations. Never let file order
choose a winner.

### 2. Fix configuration semantics before exposing the loader

- Exactly one of `spec` or `config` is accepted. Preserve positional R-list calls
  and the public default check mode. Reject conflicting inputs, not silent merging.
- Resolve service defaults, then operation overrides by stable method/path within
  that service. Maps override named fields; sequences replace, not concatenate.
  An absent field inherits; an empty sequence explicitly clears; null is allowed
  only for fields whose documented meaning supports it. No implicit global policy.
- Preserve dynamic production-schema discovery where current scripts use it:
  allow declared root-relative file patterns with explicit filename exclusions,
  expand deterministically, and record the resolved files/hashes. Missing literal
  files and selectors matching nothing are errors, not valid empty inventories.
  Schema files not configured as inputs must not silently become active.
- Reject unknown operation/parameter override targets after source indexing.
  An override targeting a deliberately excluded operation can be retained with
  an inactive diagnostic; it must not resurrect that operation.
- Use exact field lookup, strict scalar/sequence validation, and schema-aware
  numeric normalization so YAML numeric values do not churn R integer defaults.
  Test empty/one-element lists, null, false, zero, and quoted boolean-like strings.
- Load UTF-8 YAML with `eval.expr = FALSE` explicitly, independent of session
  options. Reject executable tags rather than merely warning and continuing.
  Ordinary in-document aliases are supported; fix YAML merge precedence to
  explicit-key override and reject duplicate explicit keys. No cross-file
  inheritance or executable include mechanism.
- Compile/validate all regexes before inventory changes. Use any-match semantics
  across the exclusion list. Preserve case and anchors; do not silently normalize
  regex text or use a different regex engine during migration.

The YAML package defaults can depend on session options and its merge behavior
is configurable: [official loader reference](https://yaml.r-lib.org/reference/yaml.load.html).

### 3. Migrate legacy expression fields without changing runtime hooks

**Question 3 resolved (2026-09-08)**: the user explicitly approved YAML for
declarative settings and named R callbacks for computation or branching. YAML
defines endpoint selection, regex exclusions, parameter defaults, example
values, tags, lifecycle, and hook selection. For example, YAML can select an
identifier-resolution pre-request hook; the existing client-owned R function
performs resolution. Cache handling and response transformations likewise stay
in R where behavior requires it. apipak generates wrappers and hook invocation;
ComptoxR retains its specialized behavior. The conversational YAML example was
illustrative, not an approved final configuration schema. Verify unusual
signatures, request mappings, and skip/post-hook behavior during implementation;
this decision does not establish that all current cases already fit the engine.

ComptoxR's existing `inst/hook_config.yml` contains values such as
`default: 'c("wide", "raw")'` and request arguments such as
`endpoint: 'req_data$request$endpoint'`. Blindly copying them would violate the
new data-only contract; treating them as ordinary strings would change behavior.

Move generator-only settings to service YAML as typed literal values or explicit
references: a request argument is either `value: ...` or
`from: [hook_state, request, endpoint]`. Allowed reference roots are the public
parameter map and hook state. Construct the corresponding R expressions from
validated components; do not parse arbitrary new YAML strings as code. Defaults
become typed YAML values/sequences. Nonliteral computation lives in named R
callbacks, which may return data or language objects, not hidden renderer source
strings. Do not build a general expression language.

Audit consumers before removing old generator-only fields. Leave runtime hook
chains and payload settings in the existing runtime file, with unchanged runtime
merge semantics. Service configuration refers to that file for hook declarations
rather than duplicating them. Any temporary legacy conversion is isolated,
allowlisted, and removed from the ComptoxR path before its completion gate.

`post_on_skip = TRUE` means skip HTTP but still run the post-response chain.
The neutral renderer currently returns immediately on skip. Preserve both
behaviors explicitly and test skipped requests, hook-mutated parameters,
successful result shaping, and hook errors. Final hook validation uses the
desired wrappers plus protected/manual wrappers and fails on missing selected
wrappers. Pre-generation discovery can be permissive; final acceptance cannot.

### 4. Protect namespace identity, not just filenames

Check names against existing function definitions, helpers, runtime callbacks,
generated support functions, and case-insensitive output paths. Do not silently
rename established public wrappers. Reject collisions with an actionable source
diagnostic; explicit naming overrides resolve them. Avoid generated local-name
capture and qualify base helpers where a client-defined function could shadow
them. Test legal-but-awkward parameter names, reserved names, and body/parameter
name collisions. Keep docs and fixture calls mapped to the actual public names.

Keep the schema path used for selection separate from the path passed to HTTP.
Explicitly represent prefix removal required by existing helpers. Test duplicate
`/api` or `/latest` prefixes, trailing slashes, and encoded path-segment values.
An offline relative server URL needs its recorded origin; never infer it from
the developer's working directory or contact the server during generation.

### 5. Make ownership and reconciliation conservative

**Question 4 resolved (2026-09-08)**: the user approved comparing existing
wrappers with freshly generated baseline output and suggested Git diffs to
identify meaningful changes apart from linting. Regenerate in isolated output
using the pinned baseline toolkit and formatter, then inspect ordinary Git diffs
(or `git diff --no-index` for separate directories). Use whitespace-insensitive
diffs and consistently formatted temporary copies as supporting views; neither
alone proves semantic equivalence. Review signatures/defaults, request mappings,
hook order, return handling, and roxygen/docs including examples, tags, lifecycle,
and exports. Do not discard documentation or string-literal changes as linting.
Move understood intentional customizations into configuration or named callbacks
and verify equivalent behavior before replacing generated output. Preserve
unexplained differences and ask the user only when investigation cannot resolve
their intent. Record the classification before seeding ownership; a clean or
formatting-only diff does not override lifecycle protection.

Persist a versioned generation manifest, separate from the retired ComptoxR
`dev/test_manifest.json`. Record relative output paths, operation ownership,
last-applied content hashes, schema/config/callback inputs, toolkit and formatting
versions. Hash text consistently as UTF-8/LF; exclude timestamps/absolute paths
from deterministic comparisons. Include generated helpers, tests, and metadata,
not just wrapper files.

Seed legacy ownership only after baseline regeneration/classification verifies
the file; a generated header alone cannot authorize replacing an unexplained
local edit. On later runs, a changed last-applied hash is a protected conflict.
Do not offer a blanket force flag that overwrites manual edits or lifecycle
protection. Files that are protected but already correct are satisfied, not
blocking conflicts.

Keep selection status and file ownership as separate dimensions. A selected,
manually implemented operation is valid and may count as implemented. An excluded
protected wrapper is reported as retained; do not silently label it removed.
For mixed manual/generated files, protect the whole file and report required
changes; do not introduce an in-place function-splicing engine. Fully owned
multi-function files can be rendered as a whole after retained definitions are
accounted for.

An explicit filter exclusion is removal intent. A missing schema, removed config
entry, upstream disappearance, parser failure, or unsupported operation is not
automatic deletion permission. Report potential retirement separately. Renaming
an operation through explicit configuration may move verified owned output only
as a paired write/removal after validation; protected originals block that move.

### 6. Treat one apply as a validated publication of files

Stage wrappers, tests, `man/`, `NAMESPACE`, generated hook metadata, and other
owned outputs together. The current adapter stages wrappers but documentation
is later generated by CI; preserve existing output while closing that partial
apply gap. Use roxygen for tool-owned namespace/help generation; preserve manual
directives and client-specific tag handlers such as `R/roxy_apistage.R`.

Run formatting and documentation in an isolated R process so client loading and
S3 registration do not leak into another client's generation session. Parsing
R alone is insufficient documentation validation. Escape schema/configuration
prose so it cannot introduce roxygen `@eval`, executable inline R, or unintended
tags. Generator-owned lifecycle markup is a separate trusted template.
See [roxygen formatting rules](https://roxygen2.r-lib.org/articles/rd-formatting.html).

Before mutation, fail on blocking diagnostics, acquire a simple exclusive
per-root apply lock, and recheck input/output hashes captured during planning.
Another process or user edit makes the plan stale; do not apply it. Check/plan
may use external temporary storage but do not write project reports/manifests.

Detect both legacy and new unresolved recovery journals before another apply.
Provide a documented recovery plan/apply path that validates every backup and
destination against the project root before restoring anything. Retain evidence
if restoration fails; never delete the journal just to unblock progress. Verify
rollback success, including failure injection at multiple write stages. This
remains recoverable file application, not a cross-file filesystem transaction.

### 7. Replace weak test oracles and retain manual-wrapper coverage

`dev/test_generation/04_renderer.R` currently emits
`result <- try(..., silent = TRUE)` but checks captured calls rather than successful
completion. It also has assertions equivalent to `length(value) >= 0`. Do not
preserve those weaknesses merely to obtain generated-test text parity.

Preserve wrapper/runtime contracts; intentionally strengthen generated tests.
Require successful completion, expected result shape/value, exact meaningful
request fields, and intended call count/order. Derive independent expectations
from reviewed baseline behavior/specifications, not solely the wrapper being
tested. Preserve bespoke suites and actually run them; a file mentioning the
wrapper and `test_that` is only structural evidence.

**Question 2 resolved (2026-09-08): diagnose wrapper failures before changing
code.** The user rejected treating a failing wrapper as automatic authorization
for a wrapper bug fix. Determine whether the stubbing process generated an
incorrect wrapper/request or the endpoint is unavailable. First reproduce with
deterministic local fixtures and inspect the generated signature, method, URL,
parameter placement, serialization, and hook/response handling against the
schema and intended contract. An offline failure cannot establish an outage.
Where needed, use a bounded live comparison of the wrapper and an independently
constructed equivalent request, with valid example inputs and the same service,
authentication, and environment. Record sanitized request details, response
status/body, and time; do not re-record cassettes as part of diagnosis.

If generation is wrong, fix the responsible generation/configuration step and
add a regression test rather than patching generated output. If evidence shows
an endpoint outage, record it separately and retain offline contract coverage;
do not rewrite the wrapper or weaken assertions to make the live check pass.
Authentication, invalid inputs, schema drift, client-runtime failures, and
fixture defects can also explain failures: report the supported diagnosis, or
mark it unresolved when evidence is insufficient. A failed live request alone
does not prove the endpoint is down. Missing credentials or inability to perform
an essential live comparison remain explicit verification limitations.

Maintain an observed manual-wrapper inventory alongside schema operations so
PubChem and other existing wrappers absent from CTX/Chemi/EPI schemas do not lose
tests. This is maintenance of existing code, not the deferred feature of authoring
new endpoint schemas. Do not add these wrappers to unrelated schema denominators.
Track implementation coverage separately from verified contract-test coverage.
Selected-but-unsupported operations remain visible in totals; never improve
coverage by silently removing hard cases from the denominator.

Mutation checks must catch a wrong method, wrong parameter location/body, missing
required-input enforcement, wrong hook order, and an error thrown after the
correct helper call. Extend existing fault checks rather than inventing another
test framework. The probe script's unmet contracts become positive acceptance
tests; do not preserve its FALSE results as the definition of success.

### 8. Preserve workflow behavior while making failures blocking

Inventory readers of CLI flags, report schemas, coverage badges and
`GITHUB_OUTPUT` names. Include `calculate_coverage.R`, `detect_test_gaps.R`, the
canonical unit-test readiness audit, and schema-check/pipeline/coverage/readiness
workflows. Keep client-specific schema acquisition and release automation local;
"wholesale replacement" does not mean migrating unrelated database/build tasks.

The current schema-diff CI step uses `continue-on-error: true`. A parsing or
configuration failure must prevent subsequent generation/publication; keep
best-effort diagnostics separate from that blocking validity gate. Core R
functions return structured results/errors, never `quit()`; only thin CLI entry
points choose process exit codes. Preserve intentional existing CLI defaults
while the reusable generation function remains check-by-default.

Compare old/new schemas using the same selection policy to report upstream
changes. Report old/new policy selection changes separately; changing a filter
must not masquerade as an upstream deletion. Run workflow-relevant checks with
`stop_on_failure = TRUE` or equivalent verified exit status, and do not accept a
successful R process exit alone as proof that test expectations passed.

### 9. Define the release and escalation boundary

If PR 309 is still unmerged, create the ComptoxR implementation branch from its
reviewed production-policy head as a dependent branch rather than blocking work
or dropping those changes. Rebase onto the normal integration base once merged;
do not merge or release PR 309 merely to simplify this task.

A candidate apipak archive can be installed from a local build into an isolated
library during development. Do not keep running the old pinned installer after
switching imports; it would reinstall wrapmaint. Record candidate package name,
source revision, and installed location. Update the remote pin only once its
immutable release artifact exists and download verification passes. The initial
renamed package can retain version 0.1.0 under its distinct package name; follow
the toolkit's established release tooling for later increments.

Check installed artifacts on Windows and Linux, including paths/case, line
endings, package loading, and regeneration. Run the large-case benchmark against
the baseline in the same environment; investigate material regressions before
completion rather than comparing unrelated machines.

Proceed without user interaction on internal implementation choices consistent
with these rules. Pause only for an actual public-contract change that cannot be
preserved, unexplained user-edited/protected output blocking the result, missing
credentials/permissions for an essential external action, or a naming/publication
conflict that cannot use the stated defaults. Ordinary parser gaps, callback
extraction, baseline fixes, and new generic support are implementation work.
Do not silently redefine acceptance to avoid them.

### 10. Keep new-client HTTP behavior explicit and bounded

New-client initialization requires package metadata or obtains it from an
existing DESCRIPTION; it must not silently assign apipak's authors/license to
someone else's package. For this user's Natural Products package, the existing
user-owned package metadata is the starting reference. Initialize only absent
scaffold files, and report existing-file conflicts without overwriting them.
The generated client declares its own httr2/runtime dependencies; apipak remains
development-only. Existing ComptoxR initialization must not replace its helpers.

The generated default transport performs one request, honoring the declared
method, URL, parameter placement and body media. Do not infer all-pages loops,
polling, chemistry transformations, or automatic retries of writes from endpoint
names. Reuse httr2 request/response primitives rather than implementing another
HTTP stack. Request/response adaptation beyond this contract uses explicit
client callbacks.

Default new-client returns: JSON decoded without automatic data-frame
simplification, textual content including SVG as character data, binary content
as raw bytes, and genuinely empty response bodies as NULL. HTTP failures raise
errors; malformed nonempty JSON is not converted into an apparent empty success.
No automatic tidying or cache. A declared response policy may override decoding
for an endpoint; do not guess from its name. Follow the observed response media
type and test both declared formats for multi-format operations.

Omitted optional query parameters are omitted from the wire; false and zero are
retained. Preserve explicit JSON null and array shape. Required-input presence
and nullable values are separate checks. For ambiguous nullable query encoding,
require a documented endpoint mapping rather than inventing a universal null
string. Preserve plain-text bytes/newlines and multipart file/field names; upload
the supplied file contents, not its local path string. Do not treat a server-side
`path` parameter as permission to read a client file.

Maintain per-operation schema support, independent offline verification, and
live verification as distinct evidence. Full frozen-schema coverage requires
all operations supported and offline-verified; it does not justify claiming
untested upstream behavior or correctness of chemical calculations. Live checks
remain explicit and bounded, especially for job-submitting endpoints that happen
to use GET. Use small deterministic fixtures and do not send user/private data.
See [httr2 body primitives](https://httr2.r-lib.org/reference/req_body.html).

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
     filter = 'generate_tests_pipeline|stub_generation|diff_schemas|hooks',
     stop_on_failure = TRUE
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
