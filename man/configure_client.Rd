\name{configure_client}
\alias{configure_client}
\title{Propose editable configuration from a schema}
\description{Discover every operation, group by its first tag, and propose project and service YAML without generating endpoint functions.}
\usage{
configure_client(root, schema, package = NULL,
    naming = c("operation_id", "tag_prefix"),
    group_by = c("tag", "none"), mode = c("plan", "apply"))
}
\arguments{
\item{root}{Client directory. Planning does not create it.}
\item{schema}{Local OpenAPI 3.0/3.1 or Swagger 2.0 JSON, YAML, or YML file, or a reviewed configure_apis data frame for multiple APIs.}
\item{package}{R package name; read from DESCRIPTION when present. A supplied name must agree with existing metadata.}
\item{naming}{Preserve valid operationId names, or use tag-prefixed snake_case. Missing or invalid IDs get method/path names. Prefixing removes exact tag tokens and their simple plural, not synonyms.}
\item{group_by}{Group by first operation tag, or keep one default service. Missing tags use default. Untagged/default services keep per-function source files; other groups configure a shared R file and help family.}
\item{mode}{Preview by default. Apply creates absent files only; differing existing files or colliding tag filenames stop the entire write.}
}
\value{A list with named YAML/schema text in files, operation assignments in operations, diagnostics, and changes. Each change contains file, action (create, unchanged, conflict), before, and after. Schemas with security declarations get an authentication map from scheme names to proposed environment-variable names. It contains no tokens; names can be edited before generation. API keys and HTTP bearer tokens are supported; OAuth login and refresh are deferred.}
\details{The proposal includes a schema copy, specmill.yml, and apis/*.yml. Each service selects exact METHOD /path pairs through selection.include. Multiple tags use the first tag with a diagnostic. Names and tag filenames are checked for collisions; reserved runtime names are diagnosed. Name collisions may be written for manual correction but block subsequent wrapper generation. Unsupported operations stay in the configuration with their diagnostics. This does not supply transport implementations or resolve unsupported schema features.

Existing files are never overwritten, even if originally generated. Review changes and manually incorporate the desired YAML edits. Apply with no new files is a no-op. This is initial scaffolding, not automatic schema-refresh reconciliation. No helper, package metadata, wrappers, or tests are created by this function; use initialize_client for a new package.}
\note{Schema copies retain the source format and extension; YAML inputs do not create converted JSON sidecars. For a reviewed multi-API data frame, the proposal contains one apis/<api>.yml per included API. Each file holds shared schema, selection, helper, authentication and default settings plus nested tag groups. Groups inherit API settings and cannot re-enable project- or API-excluded methods or paths. Existing flat service files remain supported.}
\seealso{\code{initialize_client}, \code{generate_client}, \code{load_project}}
\examples{
schema <- system.file('catalogue/schema.json', package = 'specmill')
proposal <- configure_client(tempfile(), schema, package = 'catalogueclient')
proposal$files[['apis/default.yml']]
}
