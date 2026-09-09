\name{generation_command}
\alias{generation_command}
\alias{script_root}
\title{Run sourceable maintenance commands}
\description{Adapt the shared generator to existing wrapper/test command flags and locate a client root from a maintenance script.}
\usage{
generation_command(root, args = character(), kind = c("stubs", "tests"),
    config = "apipak.yml", callbacks = new.env(parent = emptyenv()))
script_root(script)
}
\arguments{
\item{root}{Explicit existing client root directory.}
\item{script}{Maintenance script basename, located from source frames or the Rscript command line.}
\item{args}{Character vector of command flags. Use explicit values when calling from a sourced interactive script.}
\item{kind}{\code{stubs} reconciles wrappers and documentation; \code{tests} reconciles fixed contract tests. Both default to apply.}
\item{config}{Project YAML path relative to root, or client hook configuration for hook validation.}
\item{callbacks}{Explicit environment containing named development callbacks.}
}
\value{generation_command() invisibly returns the generation result, or NULL for help, and propagates errors. script_root() returns a normalized absolute package root or errors if it cannot locate the script/package.}
\details{Unlike generate_client(), generation_command() defaults to apply. For stubs use --plan or --check; for tests use --dry-run, --check, or --generate. --help prints usage. Legacy --rebuild prefixes are accepted but selection remains in YAML. --force never bypasses ownership. Test check/apply requires fixed contracts for every selected operation. Summary values are written to GITHUB_OUTPUT when set. script_root() walks upward from the matching script to DESCRIPTION.}
\seealso{\href{https://seanthimons.github.io/apipak/articles/maintenance.html}{Step-by-step guide}.}
