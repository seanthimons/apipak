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

The first inventory driver ran outside the ComptoxR working directory and the
legacy EPI selector returned no files. Running from the explicit client root
captures all 12 EPI operations. The migration must remove this working-directory
dependency. No schema or generated client files were changed to fix the probe.

The shell guard rejected a validation loop with a dynamic truncating log path.
The command was replaced with literal evidence log paths; no approval bypass
was used. PowerShell may mark stderr-producing commands unsuccessful even when
R exits zero, so subsequent commands explicitly propagate `$LASTEXITCODE`.
