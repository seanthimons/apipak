# Issue #16: source-contract review

Reviewed 2026-09-12. The review accounts for **30 distinct historical operations**:
nine AMOS defects, ten GET bodies, and eleven binary-query declarations. These
three historical groups do not overlap by API/method/path. Adding the previously
exposed `POST /api/alerts/groups` produces a **31-operation ledger**. Binary-query
operations can also have JSON bodies or nested query objects; those secondary
findings are not additional operations.

## Evidence and disposition

- [AMOS](AMOS.md): nine unresolved invalid Swagger declarations.
- [GET bodies](GET-BODIES.md): ten unresolved method/body contracts.
- [Binary query](BINARY-QUERY.md): twelve unresolved binary-query contracts,
  including the later alerts-group exposure.
- [Operation ledger](operations.csv): exact keys, actual audited snapshot
  SHA-256, diagnostic location, review disposition, parser result, selection
  exclusion, and implementation owner.

No authoritative replacement wire shape was established. No upstream report was
posted, production operation called, snapshot corrected, override introduced,
or generated client/helper edited. The evidence reports identify the specific
service-owned declarations needed to resolve each case. Catalogue hashes refer
to original downloads and must not be confused with normalized snapshot hashes.

## Verification

From the repository root:

```r
source('dev/review_source_contracts.R')
review_source_contracts('C:/Users/sxthi/Documents/specmill-testing')
```

The sourceable verifier checks historical group counts, unique keys, operation
presence, nonempty review diagnostics, current parser outcomes, and the active
audit delta. The existing audit checks that planning leaves proving-ground files
unchanged. This corpus review intentionally needs the external corpus; package
tests remain offline and independent of that folder.

The active audit remains **332 renderable / 205 excluded / 11 blocked**. Its
eleven blocked keys match the #12 audit exactly: four AMOS query-type defects and
seven binary-query cases. Six binary-query cases also report nested parameters.
[Changed operation keys](changed-operation-keys.csv) and
[newly exposed blockers](newly-exposed-blockers.csv) are both empty. The
alerts-group case was exposed before this review, not by this work.

Direct parsing without source policy still rejects all nine AMOS declarations
and all twelve binary-query declarations. All ten GET-body declarations now
parse successfully. Their explicit unresolved diagnostics are retained in the
review ledger, but **the parser does not emit a GET-body contract warning**.
Consequently #16 remains open: its requirement that unresolved cases retain a
clear package diagnostic is not fully satisfied. The next package change should
carry this review state through inventory/generation diagnostics without
guessing a method or request encoding. Service evidence is still required for
any source correction.

Passed offline checks:

```text
Rscript tests/parameter-diagnostics.R
Rscript tests/diagnostics.R
git diff --check
```

No new transport assertions were added because no contract was resolved and no
runtime behavior changed. A future resolved contract must add its minimal local
schema and actual received-request assertion using `tests/native-transport.R`.
