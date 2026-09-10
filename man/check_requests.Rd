\name{check_requests}
\alias{check_requests}
\title{Check a fixed request and successful result}
\description{Call a wrapper and require exact equality with independently supplied captured request and result expectations.}
\usage{
check_requests(call, expected, capture, result)
}
\arguments{
\item{call}{Zero-argument function that calls the wrapper.}
\item{expected}{Independent fixed expected request records.}
\item{capture}{Zero-argument function returning captured requests.}
\item{result}{Expected successful result.}
}
\value{Invisibly TRUE on success; raises an error on a request/result mismatch or a failing call.}
\details{The call executes first; errors propagate. Both the captured request and final result use identical() semantics, including types and classes. Supply a recorder or mock so an offline check does not contact a service.}
\seealso{\href{https://seanthimons.github.io/specmill/articles/testing.html}{Step-by-step guide}.}
\examples{
captured <- NULL
call <- function() {
  captured <<- list(method = 'GET', path = '/items')
  list(count = 0L)
}
check_requests(call, list(method = 'GET', path = '/items'),
  function() captured, list(count = 0L))
}
