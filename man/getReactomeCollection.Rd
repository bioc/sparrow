% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/get-reactome.R
\name{getReactomeCollection}
\alias{getReactomeCollection}
\alias{getReactomeGeneSetDb}
\title{Retrieve gene set collections from from reactome.db}
\usage{
getReactomeCollection(
  species = "human",
  id.type = c("entrez", "ensembl"),
  rm.species.prefix = TRUE
)

getReactomeGeneSetDb(
  species = "human",
  id.type = c("entrez", "ensembl"),
  rm.species.prefix = TRUE
)
}
\arguments{
\item{species}{the species to get pathay information for}

\item{id.type}{\code{"entrez"} or \code{"ensembl"}}

\item{rm.species.prefix}{pathways are provided with species prefixes from
\code{reactome.db}, when \code{TRUE} (default), these are stripped from the gene set
names.}
}
\value{
a reactome BiocSet object
}
\description{
Retrieve gene set collections from from reactome.db
}
\section{Functions}{
\itemize{
\item \code{getReactomeGeneSetDb()}: returns a GeneSetDb object

}}
\examples{
\donttest{
  bsc.h <- getReactomeCollection("human")
  gdb.h <- getReactomeGeneSetDb("human")
}
}
