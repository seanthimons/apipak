\name{bind_tools}
\alias{bind_tools}
\title{Bind legacy maintenance tools to a client context}
\description{Install an extracted compatibility function group into an explicit client policy environment.}
\usage{
bind_tools(group, envir)
}
\arguments{
\item{group}{Installed compatibility function group.}
\item{envir}{Explicit client context receiving installed functions.}
}
\value{The supplied environment invisibly, with bound functions added. Unknown groups or a non-environment target raise an error.}
\details{This is for existing endpoint-table integrations, not new project setup. Groups include schema, paths, inventory, scaffold, test_inventory, test_scaffold, test_validation, test_helpers, ast, runner, parser, drift, diff, and readiness. The client supplies required selection, rendering, fixture, and reporting policy. For readiness use asNamespace("apipak") as the parent and initialize audit_policy with the bound read_audit_policy() helper. Other groups also install supporting dependency exports where absent.}
\seealso{\href{https://seanthimons.github.io/apipak/articles/troubleshooting.html}{Step-by-step guide}.}
