\name{load_project}
\alias{load_project}
\title{Load and validate a YAML project}
\description{Resolve local schemas and service policies from an explicit client root without generating output.}
\usage{
load_project(root, config = "apipak.yml", callbacks = new.env(parent = emptyenv()))
}
\arguments{
\item{root}{Explicit existing client root directory.}
\item{config}{Project YAML path relative to root, or client hook configuration for hook validation.}
\item{callbacks}{Explicit environment containing named development callbacks.}
}
\value{A list containing named services, input file paths, normalized root, package name, and optional formatter policy. Each service contains resolved schema files and validated generation policy.}
\details{Paths inside project and service YAML resolve against root. Services require unique IDs, local schema selectors, and a client helper name. Unknown fields, invalid types, unsafe paths, executable YAML tags, unresolved callbacks, and invalid selectors fail. callback_files are fingerprinted inputs, not sourced scripts.}
\seealso{\href{https://seanthimons.github.io/apipak/articles/configuration.html}{Step-by-step guide}.}
