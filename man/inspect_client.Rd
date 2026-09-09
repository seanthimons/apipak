\name{inspect_client}
\alias{inspect_client}
\title{Inspect implementation and fixed-contract coverage}
\description{Compare selected YAML operations with client source definitions, exports, and fixed test files.}
\usage{
inspect_client(root, config = "apipak.yml", callbacks = new.env(parent = emptyenv()))
}
\arguments{
\item{root}{Explicit existing client root directory.}
\item{config}{Project YAML path relative to root, or client hook configuration for hook validation.}
\item{callbacks}{Explicit environment containing named development callbacks.}
}
\value{A list with operations, inventory, diagnostics, manual_exports, and coverage. Coverage is keyed by service ID and contains total selected operations, implemented exported definitions, and declared contracts with test files.}
\details{This is a read-only structural inspection. Unsupported selections remain in coverage totals. Manual exports are listed separately. A present test file is not evidence that tests ran or passed.}
\seealso{\href{https://seanthimons.github.io/apipak/articles/testing.html}{Step-by-step guide}.}
