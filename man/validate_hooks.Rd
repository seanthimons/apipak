\name{validate_hooks}
\alias{validate_hooks}
\alias{check_client_hooks}
\title{Validate client runtime hook declarations}
\description{Check declared hook chains against wrapper calls, client hooks, and the configured hook executor.}
\usage{
validate_hooks(config, wrappers, hooks, callback = "run_hook")
check_client_hooks(root, config, hooks, callback = "run_hook")
}
\arguments{
\item{root}{Explicit existing client root directory.}
\item{config}{Parsed client runtime hook configuration as a named list; not a project YAML path.}
\item{wrappers}{Named client functions parsed once by the caller.}
\item{hooks}{Explicit environment of local hook functions.}
\item{callback}{Name of the client's hook execution function.}
}
\value{validate_hooks() returns valid, errors, and counts for functions, hooks, and parameters. check_client_hooks() raises an error for invalid declarations and otherwise returns that result invisibly.}
\details{config is parsed hook policy data, not a filename. validate_hooks() takes an explicit named list of wrapper functions. check_client_hooks() parses definitions under root once and constructs the wrapper list without loading the client package. The hooks environment supplies the client hook functions. Validation is structural; behavioral hook tests remain necessary.}
\seealso{\href{https://seanthimons.github.io/apipak/articles/configuration.html}{Step-by-step guide}.}
