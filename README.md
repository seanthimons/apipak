# apipak

Generate and maintain R API clients from local OpenAPI schemas and reviewed YAML
policy. apipak creates wrappers, documentation, and request contract tests while
your package keeps control of HTTP, authentication, and response handling.
Your package's users do not need apipak installed.

## Install

```r
install.packages('remotes')
remotes::install_github('seanthimons/apipak@v0.1.2')
```

For an existing project with a toolkit lock, use its own installer to get the
reviewed version.

## Choose your starting point

- **New package:** [Start a new API client](https://seanthimons.github.io/apipak/articles/apipak.html)
  walks through initialization, generation, and an offline verification.
- **Existing package or ComptoxR:** [Adopt an existing client](https://seanthimons.github.io/apipak/articles/existing-clients.html)
  explains preserving public functions, helpers, hooks, and generated-file ownership.

Once a project has `apipak.yml`, the maintenance loop is:

```r
root <- '/absolute/path/to/your/client'
plan <- apipak::generate_client(root, config = 'apipak.yml', mode = 'plan')
plan$files
plan$diagnostics
# Review the plan, then apply and verify:
apipak::generate_client(root, config = 'apipak.yml', mode = 'apply')
apipak::generate_client(root, config = 'apipak.yml', mode = 'check')
```

## Learn the workflow

| Guide | What it covers |
|---|---|
| [Configuration](https://seanthimons.github.io/apipak/articles/configuration.html) | Services, selection, public inputs, request mappings, hooks, and documentation |
| [Testing](https://seanthimons.github.io/apipak/articles/testing.html) | Independent fixtures, generated tests, and transport checks |
| [Maintenance and CI](https://seanthimons.github.io/apipak/articles/maintenance.html) | Schema updates, commands, reports, and client documentation sites |
| [Troubleshooting](https://seanthimons.github.io/apipak/articles/troubleshooting.html) | Supported schemas, protected files, adoption, and interrupted-apply recovery |
| [Function reference](https://seanthimons.github.io/apipak/reference/index.html) | Arguments, results, and examples for every exported function |

Generation uses local JSON schemas and reports unsupported operations explicitly.
Reviewing generated output and passing helper-call tests do not establish live
API compatibility. See the guides for the supported subset and verification steps.

The compatibility engine was extracted from ComptoxR under its MIT license
(Sean Thimons). apipak was previously named wrapmaint.
