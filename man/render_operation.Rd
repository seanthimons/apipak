\name{render_operation}
\alias{render_operation}
\title{Render one wrapper as R source text}
\description{Render an operation record with explicit helper, request, hook, and documentation settings.}
\usage{
render_operation(operation, spec)
}
\arguments{
\item{spec}{Client specification with files, helper, optional hooks and renderer.}
\item{operation}{Supported operation record or named list of records.}
}
\value{A single character string containing generated wrapper source and optional roxygen comments.}
\details{This low-level function returns text only; it does not validate an entire project, run roxygen, write files, or check ownership. Prefer generate_client() for normal maintenance. The default helper takes method, path, path_params, query, and body. JSON array values should remain R lists to preserve one-element arrays.}
\seealso{\href{https://seanthimons.github.io/specmill/articles/configuration.html}{Step-by-step guide}.}
\examples{
schema <- system.file('catalogue/schema.json', package = 'specmill')
op <- read_operations(schema)$operations$get_item
cat(render_operation(op, list(helper = 'api_request')))
}
