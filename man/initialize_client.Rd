\name{initialize_client}
\alias{initialize_client}
\title{Initialize a new client package}
\description{Create absent package scaffold files, a local schema copy, project policy, and a client-owned httr2 request helper.}
\usage{
initialize_client(root, schema, package = NULL, title = NULL, author = NULL,
    license = NULL, base_url = NULL)
}
\arguments{
\item{root}{Destination client directory; it may be created when absent.}
\item{schema}{Local JSON schema for initialization.}
\item{package}{New R package name, for example \code{catalogueclient}. Must agree with an existing DESCRIPTION when supplied.}
\item{title}{Human-readable package title, required for a new package.}
\item{author}{Named list with \code{given}, \code{family}, and \code{email} strings, required for a new package.}
\item{license}{Explicit license string for a new package. \code{MIT + file LICENSE} also creates an MIT license metadata file.}
\item{base_url}{Absolute HTTP base URL for a new client-owned transport.}
}
\value{A list of applied file records, each containing file, path, and action. Stops before application for invalid metadata or conflicting scaffold paths.}
\details{This function writes immediately and refuses any existing-file conflict. Supply package, title, author (given, family, email), and license for a new package. Existing DESCRIPTION metadata is retained; it must already declare httr2 and jsonlite, which the default transport needs for HTTP and JSON. The base URL can come from the first schema server, but must be an absolute HTTP URL. Initialization does not generate wrappers or tests: follow with generate_client(). The helper is client runtime code and does not import specmill.}
\seealso{\href{https://seanthimons.github.io/specmill/articles/specmill.html}{Step-by-step guide}.}
