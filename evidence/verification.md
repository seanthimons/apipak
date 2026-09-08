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
No ComptoxR implementation or pin changes, source publication, or Natural
Products work yet. Completion gates remain pending.

## Investigation notes

The first inventory driver ran outside the ComptoxR working directory and the
legacy EPI selector returned no files. Running from the explicit client root
captures all 12 EPI operations. The migration must remove this working-directory
dependency. No schema or generated client files were changed to fix the probe.

The shell guard rejected a validation loop with a dynamic truncating log path.
The command was replaced with literal evidence log paths; no approval bypass
was used. PowerShell may mark stderr-producing commands unsuccessful even when
R exits zero, so subsequent commands explicitly propagate `$LASTEXITCODE`.
