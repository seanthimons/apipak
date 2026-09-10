\name{schema_diff}
\alias{schema_diff}
\alias{format_diff_markdown}
\alias{count_diff_changes}
\title{Compare schema snapshots and format a change report}
\description{Compare explicitly selected schema files and method/path operations, including reachable local references.}
\usage{
schema_diff(old_dir, new_dir, pattern = "\\\\.json$", stage_priority = NULL,
    exclude_pattern = NULL, policies = list())
format_diff_markdown(diff_results)
count_diff_changes(diff_results)
}
\arguments{
\item{old_dir}{Existing directory containing the previous schema snapshot.}
\item{new_dir}{Existing directory containing the candidate schema snapshot, using matching basenames.}
\item{pattern}{Regular expression selecting filenames; defaults to JSON files.}
\item{stage_priority}{Optional ordered suffix priority for files such as \code{service-prod.json} and \code{service-dev.json}. The first matching stage per service is selected. NULL disables stage selection.}
\item{exclude_pattern}{Optional case-insensitive filename exclusion regex, applied after selection by pattern.}
\item{policies}{Operation selection policies keyed by schema basename.}
\item{diff_results}{Versioned-schema report records. Changed contracts require review and are conservatively counted in the breaking-change lane; parsing errors stop comparison.}
}
\value{schema_diff() returns changed schema records containing schema_file plus added, removed, and modified tables. format_diff_markdown() returns report text. count_diff_changes() returns change counts, including the conservative breaking-change count.}
\details{Use the same file naming and selection policy for both schema snapshots. Changed canonical contracts require review and are conservatively counted in the breaking-change lane. Malformed input stops comparison. Policy changes should be reviewed separately from schema changes; these reports do not prove upstream runtime compatibility.}
\seealso{\href{https://seanthimons.github.io/specmill/articles/maintenance.html}{Step-by-step guide}.}
