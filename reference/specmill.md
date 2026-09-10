# Generate and maintain R API clients

Development-only tools for local schema parsing, reviewed YAML policy,
wrapper and documentation generation, independent request contracts, and
protected file maintenance. Generated clients own HTTP, authentication,
and response parsing and do not need specmill at runtime.

## Details

Start with initialize_client() for a new package or load_project() for
an existing YAML integration. Review generate_client() plans before
applying, then check freshness and run client tests. Unsupported schema
operations remain explicit diagnostics.

## See also

[`initialize_client`](https://seanthimons.github.io/specmill/reference/initialize_client.md),
[`generate_client`](https://seanthimons.github.io/specmill/reference/generate_client.md),
[`inspect_client`](https://seanthimons.github.io/specmill/reference/inspect_client.md),
[Documentation website](https://seanthimons.github.io/specmill/).
