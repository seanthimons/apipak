\name{read_operations}
\alias{read_operations}
\alias{compare_operations}
\title{Read and compare local schema operations}
\description{Extract operation records from local OpenAPI 3.0/3.1 or Swagger 2.0 JSON schemas and compare their input contracts.}
\usage{
read_operations(files, policy = list())
compare_operations(old, new)
}
\arguments{
\item{files}{Local JSON schema paths.}
\item{policy}{A list with optional service identity, methods allowlist, include allowlist of exact METHOD /path keys, path exclude regexes, names keyed by METHOD /path, and override_keys for declared operation settings. When include is supplied, an operation must match it as well as the method and path filters; an empty include selects nothing. Unknown included keys are errors.}
\item{old}{Results from \code{read_operations}.}
\item{new}{Results from \code{read_operations}.}
}
\value{read_operations() returns named operations and unsupported_operations plus diagnostic and inventory lists. compare_operations() returns change records with key, status (added, breaking, review, or unknown), and reason; no changes returns an empty list.}
\details{The supported subset includes scalar path/query/header input, OpenAPI form-style string query arrays, JSON scalar/nested-object/array bodies, and binary string bodies sent as application/octet-stream. Binary inputs are raw vectors. OpenAPI request bodies select application/json when offered, including alongside other media types; alternative XML/form encodings are not generated. External/cyclic input references, unsupported media, and unsupported parameter/body shapes are diagnosed. Structurally valid unsupported metadata is returned separately for reviewed client mapping. Authentication from security schemes is not generated; the client helper owns credentials. This is not a full schema validator. Comparison classifies input changes conservatively and cannot prove HTTP or response compatibility.}
\seealso{\href{https://seanthimons.github.io/specmill/articles/troubleshooting.html}{Step-by-step guide}.}
\examples{
schema <- system.file('catalogue/schema.json', package = 'specmill')
parsed <- read_operations(schema)
names(parsed$operations)
stopifnot(length(compare_operations(parsed, parsed)) == 0L)
}
