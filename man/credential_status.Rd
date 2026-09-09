\name{credential_status}
\alias{credential_status}
\alias{credential_preflight}
\title{Check credential presence without exposing its value}
\description{Detect missing or placeholder credential strings without logging the value or sending a request.}
\usage{
credential_status(value, name = "credential")
credential_preflight(value, name = "credential", abort = TRUE, guidance = character())
}
\arguments{
\item{value}{Credential string to inspect, usually read from an environment variable. Its value is never logged.}
\item{name}{Display label used in status messages.}
\item{abort}{Whether preflight should raise an error for invalid input. FALSE emits a warning instead.}
\item{guidance}{Character vector of client-owned credential setup instructions.}
}
\value{credential_status() returns valid and reason. credential_preflight() returns TRUE/FALSE invisibly and emits a success message, warning, or error according to status and abort.}
\details{These checks do not establish service authorization or key validity. guidance contains client-owned setup instructions. With abort = FALSE, preflight warns and returns FALSE instead of raising an error.}
\seealso{\href{https://seanthimons.github.io/apipak/articles/maintenance.html}{Step-by-step guide}.}
\examples{
credential_status('', 'service key')
credential_status('your_key', 'service key')
}
