# specmill 0.1.4 rename verification

Verified on Windows with R 4.5.1 and Air 0.9.0, 2026-09-10.

- The package namespace, project config, ownership manifest, lock, recovery
  journals, templates, tests, help, guides, and site use specmill. No old-name
  configuration or ownership fallback is retained.
- Full R CMD check: 0 errors, 0 warnings, 0 notes; all 17 acceptance scripts and
  rebuilt vignettes passed.
- The pkgdown site built all six guides and the complete function reference.
- ComptoxR ownership hashes were checked before the mechanical rename. Parsed
  code in all 345 R source files was identical afterward.
- ComptoxR maintenance verification: 922 assertions passed, with no failures,
  warnings, or skipped tests. Installed-client verification: 343 fixed contract
  tests passed with the development toolkit unavailable.
- The existing public-interface gate verified 603 function signatures and 451
  help pages against the earlier migration baseline; its five already-approved
  rendered-help corrections remain unchanged. All 24 fixed fixture files were
  scanned. No schema or recorded HTTP traffic was modified for this rename.

Sourceable client gates are evidence/final-client-generation.R,
evidence/verify-client-maintenance.R, and evidence/verify-client-runtime.R.
The older parity gate requires the baseline files in the original development
worktree. Historical results elsewhere in evidence/ refer to earlier releases.
