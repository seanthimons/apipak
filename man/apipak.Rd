\name{apipak}
\alias{apipak}
\alias{apipak-package}
\docType{package}
\title{Generate and maintain R API clients}
\description{Development-only tools for local schema parsing, reviewed YAML policy, wrapper and documentation generation, independent request contracts, and protected file maintenance. Generated clients own HTTP, authentication, and response parsing and do not need apipak at runtime.}
\details{Start with initialize_client() for a new package or load_project() for an existing YAML integration. Review generate_client() plans before applying, then check freshness and run client tests. Unsupported schema operations remain explicit diagnostics.}
\seealso{\code{\link{initialize_client}}, \code{\link{generate_client}}, \code{\link{inspect_client}}, \href{https://seanthimons.github.io/apipak/}{Documentation website}.}
