# Applied ComptoxR selection policy

Applied 2026-09-11 to `C:/Users/sxthi/Documents/specmill-testing` (`forgetest`),
then previewed with specmill `8ebbea7`. This is a filtered view of the original
548-operation proving ground, not a replacement for the unfiltered audit.

| Disposition | Before | After |
| --- | ---: | ---: |
| Renderable | 421 | 293 |
| Excluded by policy | 0 | 205 |
| Blocked | 127 | 50 |
| Total discovered | 548 | 548 |

Of the 205 exclusions, 128 were previously renderable and 77 were previously
blocked. Selection changed; generator capability did not. The selected set has
343 operations, of which 293 render and 50 remain blocked.

## What was applied

- Project `selection.methods` is now `[GET, POST]`. Service method lists remain
  intact; they cannot re-enable methods prohibited at project level.
- The existing Chem route regex from the corresponding ComptoxR service YAML
  was copied to all 32 matching service/tag configurations.
- EPI's four existing route patterns were copied to its four services:
  `^/api$`, `^/api/download`, `^/api/draw-chemical`, `^/api/ecosar/test`.
- CTX's source policy has no route exclusions; its 33 service configurations
  retain empty route lists and inherit the project method limit.

The Chem regex retains ComptoxR's exact matching behavior, including broad
substrings such as `file`, `add`, and `protocols`. This records the existing
maintainer policy; it does not assert that every matched endpoint is faulty.
No exclusions were inferred from diagnostic wording or unconstrained bodies.

All 69 services were matched via the reviewed API catalogue to the original
schema and corresponding ComptoxR policy. [policy-sources.csv](policy-sources.csv)
records each match, source-policy hash, and exact regexes.
[excluded.csv](excluded.csv) records each excluded operation and its reason.

## Remaining work

The remaining 50 blockers comprise 46 capability gaps and four schema defects:

| Blocker | Operations | Owner |
| --- | ---: | --- |
| Free-form objects | 25 | #14 |
| Unconstrained arrays / schema objects | 11 | #14 |
| Parameter shapes plus free-form objects | 2 | #8 and #14 |
| Parameter shapes alone | 4 | #8 |
| Composed bodies | 4 | #12 |
| Invalid AMOS type names | 4 | #16 |

**#14 remains first:** 36 standalone blockers plus two shared with parameter
serialization. Counts describe observed blockers, not guaranteed unlocks.
All 11 previously mislabeled missing-body cases remain selected, making them
useful regression cases rather than automatic exclusions.

The four remaining AMOS POST defects are `/api/amos/retrieve_fact_sheets/`,
`/api/amos/retrieve_product_declarations/`,
`/api/amos/retrieve_safety_data_sheets/`, and
`/api/amos/search_for_document_ids/{record_type}`. They are not excluded by the
imported route policy. Their invalid type declarations still require contract
review or a separately reviewed exclusion.

All multipart/form and recursive-reference blockers are excluded in this policy
view. Issues #9 and #12 remain relevant to general specmill coverage and the
unfiltered proving ground; exclusion does not implement those capabilities.

## Reproduction and verification

From the specmill checkout:

```r
source('dev/apply_proving_ground_policy.R')
root <- 'C:/Users/sxthi/Documents/specmill-testing'
source_root <- 'C:/Users/sxthi/Documents/ComptoxR'
proposal <- apply_proving_ground_policy(root, source_root)
# For a fresh rebuild, review the proposal and apply:
apply_proving_ground_policy(root, source_root, apply = TRUE)
source('dev/audit_proving_ground.R')
a <- audit_proving_ground(root, output = '.docs-lib/filtered-recheck')
stopifnot(
  length(a$plan$operations) == 293L,
  length(a$plan$excluded) == 205L,
  nrow(a$diagnostics) == 50L
)
```

The policy script preserves existing exclusions and changes only the intended
selection fields. It validates all proposals before writing. A second run
produced zero changes. File hashes confirmed that exactly 37 configuration files
changed and that all other proving-ground files remained unchanged. The full
audit then verified that plan mode made no additional changes and that all 548
operations were accounted for. [schemas.csv](schemas.csv) retains the input hashes.

No source schemas, generated R files, include/name lists, or ComptoxR files were
edited. No live requests were made. Generation apply remains blocked by the 50
diagnostics. Full package tests were not repeated for this configuration-only
task; the actual policy application, idempotence, and full preview were verified.
