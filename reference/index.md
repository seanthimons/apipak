# Package index

## Set up and generate

- [`initialize_client()`](https://seanthimons.github.io/specmill/reference/initialize_client.md)
  : Initialize a new client package
- [`configure_client()`](https://seanthimons.github.io/specmill/reference/configure_client.md)
  : Propose editable configuration from a schema
- [`load_project()`](https://seanthimons.github.io/specmill/reference/load_project.md)
  : Load and validate a YAML project
- [`generate_client()`](https://seanthimons.github.io/specmill/reference/generate_client.md)
  : Plan, generate, and check client output

## Inspect and verify

- [`inspect_client()`](https://seanthimons.github.io/specmill/reference/inspect_client.md)
  : Inspect implementation and fixed-contract coverage
- [`read_operations()`](https://seanthimons.github.io/specmill/reference/read_operations.md)
  [`compare_operations()`](https://seanthimons.github.io/specmill/reference/read_operations.md)
  : Read and compare local schema operations
- [`operation_fixtures()`](https://seanthimons.github.io/specmill/reference/operation_fixtures.md)
  : Choose candidate operation inputs
- [`check_requests()`](https://seanthimons.github.io/specmill/reference/check_requests.md)
  : Check a fixed request and successful result
- [`validate_hooks()`](https://seanthimons.github.io/specmill/reference/validate_hooks.md)
  [`check_client_hooks()`](https://seanthimons.github.io/specmill/reference/validate_hooks.md)
  : Validate client runtime hook declarations

## Maintenance commands

- [`generation_command()`](https://seanthimons.github.io/specmill/reference/generation_command.md)
  [`script_root()`](https://seanthimons.github.io/specmill/reference/generation_command.md)
  : Run sourceable maintenance commands
- [`coverage_report()`](https://seanthimons.github.io/specmill/reference/coverage_report.md)
  [`test_gap_report()`](https://seanthimons.github.io/specmill/reference/coverage_report.md)
  : Report implementation coverage and test gaps
- [`schema_diff()`](https://seanthimons.github.io/specmill/reference/schema_diff.md)
  [`format_diff_markdown()`](https://seanthimons.github.io/specmill/reference/schema_diff.md)
  [`count_diff_changes()`](https://seanthimons.github.io/specmill/reference/schema_diff.md)
  : Compare schema snapshots and format a change report
- [`check_public_boundary()`](https://seanthimons.github.io/specmill/reference/check_public_boundary.md)
  : Check client public-release boundaries
- [`credential_status()`](https://seanthimons.github.io/specmill/reference/credential_status.md)
  [`credential_preflight()`](https://seanthimons.github.io/specmill/reference/credential_status.md)
  : Check credential presence without exposing its value

## File safety and advanced integration

- [`apply_files()`](https://seanthimons.github.io/specmill/reference/apply_files.md)
  [`recover_client()`](https://seanthimons.github.io/specmill/reference/apply_files.md)
  : Apply owned output and recover interrupted changes
- [`render_operation()`](https://seanthimons.github.io/specmill/reference/render_operation.md)
  : Render one wrapper as R source text
- [`bind_tools()`](https://seanthimons.github.io/specmill/reference/bind_tools.md)
  : Bind legacy maintenance tools to a client context
- [`specmill`](https://seanthimons.github.io/specmill/reference/specmill.md)
  [`specmill-package`](https://seanthimons.github.io/specmill/reference/specmill.md)
  : Generate and maintain R API clients
