# Proving-ground issue crosswalk

Reviewed 2026-09-11 against all open GitHub issues, the package `README.md`,
the [audit README](README.md), and [audit script](../../audit_proving_ground.R).
Neither README was changed while the user reviewed it. The baseline is commit
`ee2dafc`; the audit is committed as `006885d`.

## Coverage and ownership

| Evidence or user-facing promise | Owner | Remaining work / boundary |
| --- | --- | --- |
| Audit README: 73 free-form and 11 unconstrained-body blockers | [#14](https://github.com/seanthimons/specmill/issues/14), new | JSON input shapes through parser, checks, fixtures, and transport; two mixed blockers also require #8 |
| Audit: 13 media-type blockers | [#9](https://github.com/seanthimons/specmill/issues/9), existing | Seven multipart, six form declarations; review three GET forms under #16 before choosing a wire contract |
| Audit: 11 parameter-only plus two mixed blockers | [#8](https://github.com/seanthimons/specmill/issues/8), existing | Serialization; eleven binary-looking query declarations also require #16 evidence |
| Audit: four composed bodies and four recursive ProtocolRecord bodies | [#12](https://github.com/seanthimons/specmill/issues/12), existing | Composition, references, nullability; recursion can depend on #14 object support |
| Audit: nine definite AMOS defects, ten GET-body declarations, eleven binary-query declarations | [#16](https://github.com/seanthimons/specmill/issues/16), new | Operation-level contract review, authoritative evidence, explicit unresolved dispositions; overlapping groups must not be summed |
| Audit: misleading missing-schema and external-or-cyclic messages | [#15](https://github.com/seanthimons/specmill/issues/15), new | Actionable, context-aware normal preview diagnostics; separate source defects, capability gaps, and policy exclusions |
| Audit: CHET duplicate operation ID and manual name override | [#17](https://github.com/seanthimons/specmill/issues/17), new | Surface collisions in configuration review and persist selected public names; current local override already works |
| Package README: supported subset and customization paths | [#6](https://github.com/seanthimons/specmill/issues/6), existing | Broader matrix with code/test evidence, silent-misgeneration fixtures, and helper ownership; this audit is partial evidence, not completion |
| Package README: generated helper-call tests do not prove live compatibility | [#7](https://github.com/seanthimons/specmill/issues/7), existing | Deterministic generated-client wire tests; reuse current local HTTP infrastructure |
| Package README: client-owned response handling | [#10](https://github.com/seanthimons/specmill/issues/10), existing | Decode/error/return-type verification, including non-JSON responses; unsupported-input counts say nothing about response correctness |
| Package README: client-owned HTTP and multi-API base URLs | [#11](https://github.com/seanthimons/specmill/issues/11), existing | Server selection, timeouts, bounded safe retries; multi-API initialization does not complete these criteria |
| Package README: authentication ownership | [#4](https://github.com/seanthimons/specmill/issues/4), existing | OAuth login/refresh remains deferred; API keys, issued bearer tokens, and anonymous routes are separate existing behavior |
| Generalization beyond single requests | [#13](https://github.com/seanthimons/specmill/issues/13), existing | Explicit pagination and stopping rules; no new audit count or evidence of completion |

All existing issues remain open and retain their scope. No duplicate issues were
created for #8, #9, or #12; new issues link to their related owners. No milestones,
labels, assignments, issue closures, or upstream reports were changed.

## Sequence for implementation handoffs

1. Start #14 with a small schema and exact received JSON assertions, reusing #7's
   existing infrastructure. Do not wait for all of #7 to finish before testing.
2. The #15 diagnostic implementation adds classification, code, source location,
   and guidance while preserving statuses and generation coverage. Continue #16
   contract evidence independently. #16 blocks
   choosing transport semantics for the flagged operations, not every #8/#9 case.
3. Implement #9's unambiguous multipart/POST-form cases, then #8 slices supported
   by contract evidence. Keep shared blockers attributed to both capabilities.
4. Implement #12 composition and recursion slices. Prediction-body value may
   justify moving composition earlier; recursion shares JSON shape concerns.
5. #17 can proceed independently through the configuration layer. Do not silently
   rename existing public functions to make a generation preview pass.

## How to use the audit safely

`audit_proving_ground(root, output = 'dev/audits/proving-ground')` calls installed
specmill in plan mode, checks project file hashes before/after that preview, and
writes three CSVs. It inspects diagnostic operations only. It is not a complete
OpenAPI validator, a portable fixture corpus, or a live-service test. Its local
reference traversal and type allowlist are targeted to this corpus; do not reuse
them as production validation, especially for OpenAPI 3.1 boolean schemas or
Swagger 2 file parameters in their permitted context.

For every capability change:

- Extract a small deterministic regression schema; do not make CI depend on the
  developer's Documents folder, real tokens, or live services.
- Verify final request method, URL, headers, content type, and body under the
  owning issue. A renderable wrapper is not the acceptance test.
- Run the proving-ground audit with a matching installed development version and
  a separate output directory. Compare service/method/path keys and reasons with
  the committed baseline. Report new blockers rather than only lower counts.
- Preserve schema hashes and reviewed configuration. Update baseline artifacts
  only after explaining the changes; do not change counts just to pass assertions.
- Record the issue's verification evidence before closing it. This crosswalk and
  issue creation do not complete any implementation acceptance criteria.

## Verification of this crosswalk

All open issue bodies were read before creating #14–#17; all four created issues
were re-fetched to verify their scope and acceptance criteria. Documentation links
and staged whitespace were checked. No runtime files, audit data, or user project
configuration changed in this follow-up, so package tests were not rerun.
