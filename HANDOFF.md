# specmill maintenance

specmill generates and maintains R API clients from local schemas and
reviewed project policy. It is a development tool; generated clients own
their HTTP helpers, authentication, response handling, and runtime
hooks.

The current name is **specmill**, selected on 2026-09-10. This is a
complete rename, including ComptoxR: package namespace, specmill.yml,
.specmill ownership records, recovery paths, callbacks, fixtures,
commands, CI, and documentation. There is no fallback to the former
package name or storage paths.

The README and six guides in vignettes/ are the current usage
documentation. The package has 24 exported functions, documented in
man/. Use the bundled catalogue for new-client acceptance; use ComptoxR
for existing-client acceptance.

Validation covers R CMD check, executable guides, independent fixed
contracts, unchanged client wrapper behavior, and a second generation
apply with no changes. Keep the toolkit source archive and ComptoxR’s
dev/toolkit-lock.json in sync.

Historical migration plans and results remain in Git history and
evidence/. They record earlier releases and are not instructions to
restore old branding.
