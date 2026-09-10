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

The separate Petstore trial downloads a pinned OpenAPI Initiative example,
preserves YAML sequences when converting it to JSON, initializes a new client,
supplies three independently specified contracts, generates code and help,
verifies a no-op second apply, checks the archive, and installs it locally.

```r
source('dev/try_petstore.R')
try_petstore(output = 'artifacts/my-petstore-trial')
```

The output contains the schema and its provenance, generated petstoretrial
package, generation plan, installable source archive, check logs, and result.json.
All client requests are mocked. The helper uses an explicit example.invalid URL;
this trial does not validate a live Petstore service or implement pagination.
