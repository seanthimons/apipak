\name{operation_fixtures}
\alias{operation_fixtures}
\title{Choose candidate operation inputs}
\description{Choose fixture values using reviewed overrides followed by schema examples, defaults, enums, and type fixtures.}
\usage{
operation_fixtures(operations, overrides = list())
}
\arguments{
\item{operations}{Supported operation record or named list of records.}
\item{overrides}{Reviewed per-operation fixture input values.}
}
\value{A named list of per-operation input lists. Stops when a fixture cannot be selected or fails supported constraints.}
\details{The selected value must satisfy supported type, enum, numeric, string-length, and pattern constraints. An invalid selected candidate raises an error rather than falling through to a lower-priority source. Schema examples are never executed. Candidate inputs are not independent expected request or response contracts.}
\seealso{\href{https://seanthimons.github.io/specmill/articles/testing.html}{Step-by-step guide}.}
\examples{
schema <- system.file('catalogue/schema.json', package = 'specmill')
operation_fixtures(read_operations(schema)$operations)
}
