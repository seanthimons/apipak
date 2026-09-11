# API files and endpoint groups

The proving ground now uses **27 API YAML files containing 69 nested endpoint
groups**. The earlier 69-file layout treated each schema tag as a separate service
file. Groups still control public names and generated R-file layout, but they no
longer require separate YAML files.

The hierarchy is:

1. `specmill.yml`: package-wide restrictions, currently GET/POST only.
2. `apis/<api>.yml`: shared schema sources, helper, credential references, and
   method/path selection for one API.
3. `groups`: existing service IDs, exact operation lists, names, file layout,
   additional restrictions, and operation overrides.

For example, edit the top-level `selection.exclude` in `apis/alerts.yml` once to
affect all three Alerts groups. CTX and EPI remain independent. None of the 69
groups currently needs an additional route exclusion; their lists are empty.
API methods and project methods still constrain every group's method list.

New multi-API initialization generates this layout. Single-schema initialization
and existing flat YAML remain supported. The number of YAML files does not
determine the number of generated R files: each group's `defaults.file` continues
to control that layout. See the configuration vignette for a complete example.

## Migration evidence

`dev/consolidate_proving_ground_apis.R` groups existing files using the saved API
catalogue, promotes only shared settings and exclusions, and retains group
differences. It first validates a temporary copy against the original resolved
service configuration. It preserves service IDs, names (including CHET's reviewed
override), includes, helper routing, credentials, defaults, and operation settings.

The live migration replaced the 69 listed service files with 27 API files and
updated the project file. Original configuration is backed up outside the client
at `.docs-lib/api-config-backup/` in the specmill checkout. The script provides a
rollback on write/validation failure. No schemas or runtime R files were edited.
The client's `build.R` comments now point to the API-level exclusion setting.

Both resolved configuration equivalence and generation preview passed:

- 293 renderable operations.
- 205 policy exclusions, now attributed to the API level where appropriate.
- 50 blockers (46 capability gaps and four schema defects).
- Repeating consolidation or importing the ComptoxR policy proposes no changes.

Historical `policy-sources.csv` and `excluded.csv` retain the prior file names and
service-level reason labels as audit evidence. Their selected operation sets are
unchanged; consult this note and the active YAML for current file locations.

## Resume or reproduce

Use a specmill build with nested API configuration support. The proving-ground
build script installs `feat/multi-api-initialization`; rerun its install section
when working from an older R session.

```r
source('dev/consolidate_proving_ground_apis.R')
root <- 'C:/Users/sxthi/Documents/specmill-testing'
# For a flat rebuild, preview first; use a new backup directory when applying.
p <- consolidate_proving_ground_apis(root, '.docs-lib/new-api-config-backup')
# consolidate_proving_ground_apis(root, '.docs-lib/new-api-config-backup', apply = TRUE)
plan <- specmill::generate_client(root, config = 'specmill.yml', mode = 'plan')
stopifnot(length(plan$operations) == 293L,
          length(plan$excluded) == 205L,
          length(plan$diagnostics) == 50L)
```

Implementation checks are in `tests/api-configuration.R` (inheritance, API
isolation, group narrowing, flat compatibility, invalid configuration, and
read-only plans) and `tests/multi-api.R` (independent live-localhost transports,
credentials, and batch limits). No public service calls are needed.

The complete clean-source package check passed with zero errors, warnings, or
notes, including all acceptance scripts and vignette rebuilds. The checking
process exited zero; its session-information helper emitted a separate Quarto
version-query warning after `Status: OK`.
The checked archive was installed into the normal R 4.5 user library, and a fresh
installed-package preview independently reproduced 293/205/50. Existing R
sessions can reload specmill through the build script's install section.
