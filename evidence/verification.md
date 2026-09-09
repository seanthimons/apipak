# Generalization verification

## Baseline, 2026-09-08

- Toolkit base: `4722e0e` (implementation `aae88f9`), branch
  `feat/apipak-generalization` in `.worktrees/apipak-generalization`.
- ComptoxR base: `4fd720b97fb2f7f2abf131925e9270b0c11b057a`, branch
  `feat/apipak-maintenance` in its `.worktrees/apipak-maintenance`.
  PR 309 and remote main were rechecked; integration predates that merge.
- `production-baseline.R` installs the checksum-verified legacy 0.1.0 archive
  into `evidence/baseline/library/wrapmaint`, records all tracked SHA-256 hashes,
  and runs the handoff's offline tests and CLI commands in fresh processes.
- Targeted tests: 420 passing assertions, 0 failures, 0 skips, 4 warnings
  (jsonlite/dplyr built under R 4.5.3; purrr/here under R 4.5.2).
- Stub freshness, generated-test freshness, hook validation, and public API
  checks: each exit 0. All tracked file hashes unchanged.
- Hook check: 37 functions, 111 hooks, 34 extra parameters. Existing generator
  warnings flag pagination-like `top` and `limit` parameters without mappings.
- Installed legacy catalogue, boundaries, schema versions, and loading
  acceptance pass. 2,000-operation baseline: 16.75 seconds on Windows 11,
  R 4.5.1, Air 0.9.0. These are helper/offline checks, not live API evidence.
- `freeze-contracts.R` saves selected operation tables and parsed function
  definitions/formals, roxygen text, and lifecycle ownership classifications.
  Selected counts: CTX 140, Chemi 191, EPI 12. Raw evidence is retained locally
  in `evidence/baseline/`; the original source revision reproduces the inputs.

## Implementation status

### Full client candidate, 2026-09-08

The complete policy represents 343 selected operations: 292 native, 44 explicitly
mapped and 7 retained with unsupported-schema diagnostics. The 342 existing
wrappers pass differential formals, calls, successful results and NULL-input
checks. Four malformed AMOS type labels remain diagnosed; their implementations
are retained. Source ownership retains 90 files and renders 201 wrapper files,
including the independently verified public resolver POST.

`comptox-documentation-probe.R` seeds 236 existing documentation policies.
`comptox-generation-probe.R` verifies formals, existing exports and rendered docs.
Five AMOS keyset pages intentionally recover literal `{}` defaults that were in
the source prose but swallowed as empty Rd groups. No other rendered help change
is accepted; the only added export is the public resolver count POST. Paragraphs,
inline-code markup and escaped brackets were corrected during this comparison.

`comptox-fixed-contracts.R` freezes baseline helper-call sequences and successful
typed results as R data fixtures; the separately diagnosed EPI route/auth/body
correction has its own explicit expectation. Two insufficient fixtures initially
returned NULL for similarity maps and safety RQ codes; valid response fixtures
now exercise successful processing. The baseline test environment fixes
`batch_limit=200`, restored after each generated contract. An initial isolated run
caught the existing suite's different batch-limit setting instead of weakening
the request assertions.

`comptox-stage.R` verifies legacy hashes against the frozen baseline, adopts only
reviewed sources/docs/namespace in an isolated copy, and runs apply/check/second
apply. The formatted candidate passes **687 assertions, zero failures, warnings
or skips**, covering all 343 fixed contracts. Original client runtime files are
still unchanged. The 12-script Windows package check is Status OK. Subsequent
input revalidation under the apply lock and explicit callback-file dependencies
are receiving targeted checks before the next commit.

Still pending: production maintenance replacement and definition/caller
dispositions, remaining ownership/recovery gates, final cross-platform benchmark
and package/client checks, immutable release and pin adoption, and NP schema-only
stress evidence. This is a candidate milestone, not migration completion.

Rename candidate installed into `evidence/candidate-library/apipak`.
All four installed acceptance scripts pass. The first archive check had no
errors or warnings and one NOTE: its worktree `.git` pointer was included.
An explicit build exclusion corrects that packaging issue; archive check rerun
is required. Rename commit: `fc574ca`.
The corrected rename archive has `R CMD check --no-manual` Status OK on Windows.
Source repository created at `https://github.com/seanthimons/apipak`; rename
and packaging commits `fc574ca`, `4178b3a` are pushed. No release exists yet.
No ComptoxR implementation or pin changes or Natural Products work yet.
Completion gates remain pending.

The ownership/recovery and YAML changes are in progress. `tests/reconciliation.R`
passes the six positive audit cases, two injected destination-write failures,
rollback, legacy journal recovery, case collisions, and no-op second apply.
`tests/configuration.R` passes YAML selection, alias/merge precedence, invalid
configuration, executable-tag rejection despite `yaml.eval.expr=TRUE`, explicit
root handling and read-only checks. The original four acceptance scripts also
passed the initial safety changes; they must be rerun after YAML integration.

The combined YAML/ownership/initialization candidate now passes all seven R
acceptance scripts under `R CMD check --no-manual`, Status OK on Windows.
New-client tests include real loopback HTTP, installed loading without apipak,
and malicious schema prose that remains non-executing during documentation.
The generated transport's encoded path was initially decoded when httr2 query
parameters were added; reusing the existing catalogue URL-construction order
fixed it. The local server's nonexistent REQUEST_URI field was replaced by
PATH_INFO plus QUERY_STRING, and its 204 response now has a NULL body.
These were diagnosed test/transport issues; no ComptoxR runtime was changed.

## Investigation notes

User clarification: an operation absent from the public schema must not exist.
The prior public-API pause is resolved. On 2026-09-09 at 00:51:58 UTC, a bounded
GET of the [public resolver schema](https://hcd.rtpnc.epa.gov/api/resolver/api-docs)
returned HTTP 200 and included both GET and POST `/api/resolver/ghs-list-count`.
The raw SHA-256 is `1497f7db23636ae8dba40ed309895329e1091a9317bbec0bc2fef2cd738f519e`,
matching the recorded production acquisition. POST metadata matches the local
snapshot after canonicalizing object-key order. Initial direct R list comparison
reported an ordering difference, not schema drift. Source/time/hash are recorded
by `missing-selected-operation.R --verify-public`.

The POST declaration now lives in `apis/chemi-resolver.yml`, with an explicit
empty JSON-object default and independent count-response contract.
`resolver-count-contract.R` exercises the rendered candidate through unchanged
`generic_chemi_request` and intercepted httr2 requests: correct URL, POST, no
CTX authentication, default/nested JSON bodies, successful H-code/count values,
and NULL rejection before transport all pass. No live endpoint POST is performed.
No runtime wrapper or export has been adopted yet.

The final `edff590` metadata candidate passes Windows and Ubuntu checks in
[CI run 34288644917](https://github.com/seanthimons/apipak/actions/runs/34288644917).
Chemi's improved differential fixture uses existing descriptor/WebTEST test
builders and valid engine/endpoint inputs; all baseline fixture errors are now
resolved. Preserving full hook state and post-processing on skipped requests
raises parity to 183/186. Remaining candidate differences are predictor request
validation, manual resolver option construction and stable safety response
processing. These remain blocking; no denominator is reduced.

The array-binding milestone `9f8f7df` passes Windows and Ubuntu checks in
[CI run 34287192970](https://github.com/seanthimons/apipak/actions/runs/34287192970).
Client interface policy is committed/pushed at `e93292e`; no client runtime,
exports, documentation, production command or development pin has changed.

The schema-metadata candidate adds a tenth installed acceptance script,
`tests/mapped-schemas.R`. Complete explicit client mappings retain native
serializer limitations in `mapping_diagnostics` and inventory status
`client-mapped`. Invalid metadata and broken references cannot be promoted.
Native coverage remains 292/343. Four AMOS routes have invalid upstream type
labels (`dict`, `array of strings`), separately diagnosed rather than coerced.
JSON Pointer unescaping now follows [RFC 6901 section 4](https://www.rfc-editor.org/rfc/rfc6901#section-4),
including a regression distinguishing `~01` from `~1`.

The first package check caught R partial matching of `policy` to `policy_version`;
exact indexing fixes that regression. Explicit input facades also retain a named
NULL body slot, preventing partial matching to `body_required`. The ten-script
Windows package check then passed. A later compact-object edge correction
returns the original unnamed `list()` when all entries are omitted; targeted
mapping tests and all 152 CTX/EPI differential cases pass after it. The EPI
diagnosis passes using the actual explicit client callback file.
The final compact-object candidate also passes the complete ten-script Windows
check, Status OK. Subsequent guards rejecting array-shaped schema objects and
properties pass `tests/mapped-schemas.R`; native ComptoxR support is unchanged.

Changed toolkit files for this checkpoint are `R/configuration.R`, `R/context.R`,
`R/generation.R`, `R/input_schema.R`, `R/mappings.R`, `R/operations.R`,
`tests/mapped-schemas.R`, `tests/mappings.R`, `README.md`, this report and HANDOFF,
plus the sourceable interface/contract/diagnosis evidence drivers. Client changes
remain the two interface YAML files and `dev/apipak_callbacks.R` at `e93292e`.

Chemi interface investigation now maps 186 of 187 structurally readable selected
operations. Its blocking differential probe reports 169 successful parity cases,
15 baseline fixture errors and 2 candidate mismatches. Fixture errors include
invalid descriptor/WebTEST inputs and response fixtures; they are not outages.
The mismatches are a manual resolver option builder and stable safety response
processing; neither runtime implementation has been changed. The migration
seed now recognizes optional option builders and R's pre-assignment list
snapshot semantics. Public `options` inputs shadowed by existing local builders
remain a separate diagnosis item before final migration acceptance.

`missing-selected-operation.R` programmatically verifies a public-API decision
point: frozen selection includes POST `/api/resolver/ghs-list-count` under
`chemi_resolver_ghs_list_count_bulk`, but frozen definitions and current exports
contain only the GET wrapper `chemi_resolver_ghs_list_count`. Adding the selected
POST wrapper would introduce a public function absent from the baseline. No
wrapper or export was added. HANDOFF's public-contract pause rule applies.

Completion remains pending: the Chemi cases, protected/mixed ownership adoption,
full documentation/contracts parity, maintenance definition/caller disposition,
production CLI/workflow replacement, final benchmark/platform checks, immutable
artifact and verified client pin, then Natural Products schema-only stress tests.

The nested-body/interface commit `0098221` passes Windows and Ubuntu installed
checks in [CI run 34285051537](https://github.com/seanthimons/apipak/actions/runs/34285051537).
The array-binding regression in `tests/mappings.R` passes locally, including
nested records, retained NULL positions and rejection of a map where a sequence
is required.

`epi-batch-diagnosis.R` independently checks the `/api/submit/batch` array schema
and intercepts actual httr2 requests from the unchanged client helper. The
baseline uses CTX authentication/service and a flat JSON object. Correcting the
candidate's declarative server/auth/body mappings produces one EPI request with
an outer array, while retaining exact formals and the same successful tibble.
No live request or outage claim is involved. This is a diagnosed generation
defect under Question 2, distinct from the 152-operation parity probe.
`comptox-interface-config.R` verifies the resulting 152 CTX/EPI interface mappings
in client YAML. Runtime wrapper generation/adoption remains pending.

The initial YAML writer simplified EPI's one-element schema-file sequence to a
scalar. Strict loading rejected it. The writer now preserves sequence identity;
the emitted field was repaired and the full read-only verification passes.
An attempted scoped restore was blocked by the shell guard; a direct correction
to that field retained the new mappings instead. Callback source environments
use base R as their parent while callback resolution remains explicitly scoped.

The `96034d3` milestone passed both Windows and Ubuntu installed package checks
in [CI run 34278913658](https://github.com/seanthimons/apipak/actions/runs/34278913658).
The next mapping/docs candidate passed all eight acceptance scripts with Windows
R CMD check Status OK. `comptox-pilot.R` validates the unchanged original against
the YAML-generated candidate for four inputs, then exercises temporary output
plan/apply/check/second apply, rendered Rd parity, and retained/generated tests
(8 and 3 assertions respectively; zero failures/skips/test warnings).
Dependency-build warnings remain for testthat 4.5.3 and vcr 4.5.2.

The pilot revealed a Windows Rd encoding issue, fixed by explicit UTF-8 parsing.
Runtime hook declarations for six absent wrappers are reported as unused instead
of being mistaken for selected output. The runtime registry itself is unchanged.
A documentation mismatch was an unnecessary escaped underscore in plain text;
the corrected rendered help matches the original. Hook parameter replacement
is shallow, preserving ComptoxR's whole-value assignment semantics.

The mappings/docs commit `f101c22` passes Windows and Ubuntu in
[CI run 34281394668](https://github.com/seanthimons/apipak/actions/runs/34281394668).
The client selection declaration is committed as `41a6cd0`; the sourceable
`comptox-schema-support.R` and `comptox-selection-config.R` probes verify all
343 selected original-path identities. Initial neutral support was 277/343.
Scalar and nested JSON handling raises it to 292/343: all CTX 140 and EPI 12,
plus Chemi 140. Remaining 51 Chemi diagnostics are 25 free-form objects,
11 missing/unconstrained body schemas, 11 parameter types and 4 compositions.
No unsupported cases are removed from selection totals.

`comptox-interface-probe.R` captures candidate declarative interfaces for the
152 CTX/EPI operations from the frozen definitions, without modifying wrappers.
`comptox-contract-probe.R` checks exact formals, complete helper-call sequences,
successful values and NULL inputs against unchanged baseline functions. All 152
pass with the current candidate. This differential evidence does not replace
the required independently authored final contracts or live API proof.

The probe caught YAML's default numeric precision changing EPI's theta default;
export now uses 17 significant digits, as documented by
[yaml::as.yaml](https://yaml.r-lib.org/reference/as.yaml.html). Empty maps require
named empty lists. Two wrappers assemble bodies field by field, so their typed
mapping uses `compact_object` to omit NULL while retaining false/zero. The EPI
search mock was a fixture defect: its hook expects an array of named search-hit
records. The corrected probe supplies that documented shape; runtime code was
not changed. Explicit input mappings retain R's supplied-NULL behavior while
schema-derived inputs retain their existing presence guards.

`maintenance-inventory.R` records definitions and references across scoped dev
modules, R sources, tests and workflows. The initial inventory finds 90 local
definitions plus 73 compatibility bindings; their final dispositions remain
pending. It exposed a parser bug on namespaced top-level calls. That shared
parser now handles such expressions without executing them, and malformed
source is a blocking error rather than an empty successful inventory. A targeted
regression passes. This fix follows the eight-script package check above.

The first inventory driver ran outside the ComptoxR working directory and the
legacy EPI selector returned no files. Running from the explicit client root
captures all 12 EPI operations. The migration must remove this working-directory
dependency. No schema or generated client files were changed to fix the probe.

The shell guard rejected a validation loop with a dynamic truncating log path.
The command was replaced with literal evidence log paths; no approval bypass
was used. PowerShell may mark stderr-producing commands unsuccessful even when
R exits zero, so subsequent commands explicitly propagate `$LASTEXITCODE`.
