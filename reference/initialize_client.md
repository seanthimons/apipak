# Initialize a new client package

Create absent package scaffold files, a local schema copy, project
policy, and a client-owned httr2 request helper.

## Usage

``` r
initialize_client(root, schema, package = NULL, title = NULL, author = NULL,
    license = NULL, base_url = NULL)
```

## Arguments

- root:

  Destination client directory; it may be created when absent.

- schema:

  Local JSON schema for initialization.

- package:

  New R package name, for example `catalogueclient`. Must agree with an
  existing DESCRIPTION when supplied.

- title:

  Human-readable package title, required for a new package.

- author:

  Named list with `given`, `family`, and `email` strings, required for a
  new package.

- license:

  Explicit license string for a new package. `MIT + file LICENSE` also
  creates an MIT license metadata file.

- base_url:

  Absolute HTTP base URL for a new client-owned transport.

## Value

A list of applied file records, each containing file, path, and action.
Stops before application for invalid metadata or conflicting scaffold
paths.

## Details

This function writes immediately and refuses any existing-file conflict.
Supply package, title, author (given, family, email), and license for a
new package. Existing DESCRIPTION metadata is retained; it must already
declare httr2 and jsonlite, which the default transport needs for HTTP
and JSON. The base URL can come from the first schema server, but must
be an absolute HTTP URL. Initialization does not generate wrappers or
tests: follow with generate_client(). The helper is client runtime code
and does not import specmill.

## See also

[Step-by-step
guide](https://seanthimons.github.io/specmill/articles/specmill.html).
