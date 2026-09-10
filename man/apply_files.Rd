\name{apply_files}
\alias{apply_files}
\alias{recover_client}
\title{Apply owned output and recover interrupted changes}
\description{Plan or apply contained file changes with ownership checks, backups, an exclusive lock, and recovery validation.}
\usage{
apply_files(root, desired, remove = character(), mode = c("check",
    "plan", "apply"), headers = "# Generated with specmill; do not edit by hand.",
    owned = NULL, validate = NULL)
recover_client(root, mode = c("plan", "apply"))
}
\arguments{
\item{root}{Explicit existing client root directory.}
\item{mode}{Check or plan without writes; apply validated output.}
\item{desired}{Named list of relative paths and generated text.}
\item{remove}{Relative paths to remove only if owned.}
\item{headers}{Reserved compatibility argument; headers alone never establish ownership.}
\item{owned}{Optional client ownership predicate for existing files.}
\item{validate}{Optional zero-argument input revalidation called after acquiring the apply lock and before any file changes.}
}
\value{apply_files() returns file/path/action records, including manifest changes. recover_client() returns journal-keyed restoration plans (invisibly for apply), with path, backup, and existed fields. Invalid recovery data or failed restoration raises an error and retains the journal.}
\details{Most callers should use generate_client() for reconciliation. apply_files() parses R output before mutation and checks manifest ownership; headers alone do not authorize replacement. A custom owned predicate is an advanced client trust boundary. Apply refuses conflicting protected writes. Recovery plan validates journals and returns restoration actions; recovery apply restores backups and removes completed journals. Confirm no live writer before resolving a stale lock. Never delete journals to bypass recovery. There is no cross-file filesystem transaction.}
\note{Ownership is recorded in .specmill/manifest.json. Locks and transaction journals use the .specmill- prefix.}
\seealso{\href{https://seanthimons.github.io/specmill/articles/troubleshooting.html}{Step-by-step guide}.}
