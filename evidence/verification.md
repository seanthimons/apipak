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
