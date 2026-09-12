# Active proving ground after schema gap fixes

Verified read-only on 2026-09-11: **328 renderable, 205 excluded, 15 blocked**
across 27 API files and 69 nested groups. File hashes are unchanged.

Compared with `../parameters/operations.csv`, no blocker key or reason changed.
The four AMOS source defects remain separate under #16; the other blockers still
require binary parameter contract review or request composition support.

[Exact blockers](operations.csv), [changed blocker keys (empty)](changed-operations.csv),
[schema inventory](schemas.csv).

```r
source('dev/audit_proving_ground.R')
audit_proving_ground(
  'C:/Users/sxthi/Documents/specmill-testing',
  'dev/audits/proving-ground/schema-gaps'
)
```

The new native-source corpus has a separate [report](../../schema-gaps/RESULTS.md).
