# Build and release workflows

The check.yml workflow runs package checks on Windows and Linux only when
manually dispatched. Automatic platform checks are paused during early development.
pkgdown.yml builds executable guides and publishes the site after main changes.

The additions borrow the manual build, version choices, artifact uploads,
Conventional Commit check, and secret scan used by these repositories:

- [boosterpak workflows at e23540d](https://github.com/seanthimons/boosterpak/tree/e23540d/.github/workflows)
- [concert workflows at 31c9942](https://github.com/seanthimons/concert/tree/31c9942/.github/workflows)
- [ComptoxR workflows at 4fd720b9](https://github.com/seanthimons/ComptoxR/tree/4fd720b9/.github/workflows)

Unlike their check-then-rebuild sequence, specmill builds one archive from a clean
Git snapshot, checks that archive, verifies its checksum did not change, and
uploads the same bytes. release.json records package, version, source commit,
asset filename, and SHA-256; SHA256SUMS can be checked with sha256sum --check.

## Test a build

Run **Build and release** in GitHub Actions. Leave publish unchecked and choose
none to build the current version. Download the source artifact from the run.
This mode never pushes commits, creates tags, or publishes releases. Changes to
the release workflow or its R helper also run this build on pull requests.

For the same check locally, commit source changes first, then run from the repo:

```r
source('dev/build_release.R')
build_release(output = 'artifacts/my-build')
```

Use a fresh output directory for each run. The helper is development tooling and
requires pkgbuild and rcmdcheck in addition to specmill's package dependencies.

## Publish

Run the workflow on main, choose patch/minor/major (or none after a reviewed
version change), and enable publish. An existing tag blocks publication. The
workflow commits the version locally before building, then pushes only after
the archive passes checks. A concurrent main change causes the normal Git push
to fail; no force push is used. Branch protection still applies.

All assets are attached to a draft before publication because releases become
[immutable](https://docs.github.com/en/repositories/releasing-projects-on-github/managing-releases-in-a-repository).
A failed upload leaves a draft for inspection. Do not retag or replace a published
archive; use a new version for corrections. The default GITHUB_TOKEN is used;
no release PAT is required. Its pushes do not trigger other push workflows, so
run Documentation manually after a version bump when updating the site's version.

Specmill has manually maintained help pages. Automatic roxygen regeneration,
autonewsmd/Quarto, rolling releases, and ComptoxR's database/schema schedules were
not copied; none is needed for this package's current release path.

## Try a different schema

For the full 19-endpoint configuration demonstration, including pet/store/user
names, parameter renaming, grouped source and help, explicit mappings, and
retained client functions, see [petstore/README.md](petstore/README.md).
Run source('dev/build_petstore.R') and build_petstore() for that example.
The three-operation smoke trial below remains a smaller separate example.

The Petstore trial downloads the [live service's schema](https://petstore3.swagger.io/api/v3/openapi.json),
records its retrieval time and checksum, and builds a client for three GET operations:
findPetsByStatus, getPetById, and getInventory. It supplies independent offline
contracts, verifies an unchanged second generation, checks the archive, and
installs it into a separate library. The installed functions then retrieve real
data and compare their results with direct HTTP requests to the same endpoints.

```r
source('dev/try_petstore.R')
try_petstore(output = 'artifacts/petstore-live')
```

The output contains the schema and its provenance, generated petstoretrial
package, selected and full-schema generation plans, installable source archive,
check logs, live-responses.rds, and result.json. Unsupported operations remain
visible in full-schema-plan.rds; this is a three-operation client, not full API coverage.
Package checks use offline fixtures; the subsequent live check requires internet
access and can fail if the shared demo data changes between requests. It checks
selected fields and exact response equivalence, not every OpenAPI constraint.
Records violating the checked Pet fields are reported in live.schema_invalid_pet_ids;
the live demo can return data that violates its own schema. Those findings are
separate from the assertions that the client returns the same data as direct HTTP.
No live write operations are performed.

To use the built client in a new R session from the repository root:

```r
library(petstoretrial, lib.loc = 'artifacts/petstore-live/library')
pets <- findPetsByStatus('available')
getPetById(pets[[1]]$id)
getInventory()
```

To repeat just the live check after loading the client, source dev/try_petstore.R
and call check_live_petstore(). The archived schema is the exact downloaded JSON;
the old illustrative /v1/pets schema is no longer used.
