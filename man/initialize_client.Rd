\name{initialize_client}
\alias{initialize_client}
\title{Initialize a new client package}
\description{Create absent package scaffold files, a local schema copy, project policy, and a client-owned httr2 request helper.}
\usage{
initialize_client(root, schema, package = NULL, title = NULL, author = NULL,
    license = NULL, base_url = NULL,
    naming = c("operation_id", "tag_prefix"), group_by = c("tag", "none"))
}
\arguments{
\item{root}{Destination client directory; it may be created when absent.}
\item{schema}{Local JSON, YAML, or YML schema, or a reviewed data frame returned by configure_apis for multiple APIs. Multi-API setup requires an existing root containing those schemas, and a new package. Each included API receives a separate request helper, namespaced function names and credential identities.}
\item{package}{New R package name, for example \code{catalogueclient}. Must agree with an existing DESCRIPTION when supplied.}
\item{title}{Human-readable package title, required for a new package.}
\item{author}{Named list with \code{given}, \code{family}, and \code{email} strings, required for a new package.}
\item{license}{Explicit license string for a new package. \code{MIT + file LICENSE} also creates an MIT license metadata file.}
\item{base_url}{Absolute HTTP base URL for a new client-owned transport.}
\item{naming}{Preserve operationId names by default, or propose tag-prefixed snake_case names. See configure_client.}
\item{group_by}{Group operations by first tag (default), or use one default group with none. Multi-API initialization writes one YAML file per API with nested groups; single-schema initialization keeps flat group files.}
}
\value{A list of applied file records, each containing file, path, and action. The configuration attribute contains proposed files, operation assignments, and diagnostics. Stops before application for invalid metadata, tag filename collisions, or conflicting scaffold paths.}
\details{This function writes immediately and refuses any existing-file conflict. Supply package, title, author (given, family, email), and license for a new package. Existing DESCRIPTION metadata is retained; it must already declare httr2 and jsonlite, which the default transport needs for HTTP and JSON. The base URL can come from the first schema server, but must be an absolute HTTP URL. Initialization does not generate wrappers or tests: follow with generate_client(). The helper is client runtime code and does not import specmill.}
\seealso{\href{https://seanthimons.github.io/specmill/articles/specmill.html}{Step-by-step guide}.}
\note{Service YAML includes explicit operation allowlists and editable names, including unsupported operations. Name collisions and unsupported transports require review before wrapper generation; initialization does not resolve them. Inspect attr(result, 'configuration')$diagnostics, or preview with configure_client() before initialization.}
