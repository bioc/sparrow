% Generated by roxygen2 (4.1.1): do not edit by hand
% Please edit documentation in R/do.goseq.R
\name{goseq}
\alias{goseq}
\title{Perform goseq Enrichment tests across a GeneSetDb.}
\usage{
goseq(gsd, selected, universe, feature.bias = NULL, method = c("Wallenius",
  "Sampling", "Hypergeometric"), repcnt = 2000,
  use_genes_without_cat = TRUE, plot.fit = TRUE, do.conform = TRUE)
}
\arguments{
\item{gsd}{The \code{GeneSetDb} object to run tests against}

\item{selected}{The ids of the selected features}

\item{universe}{The ids of the universe}

\item{feature.bias}{a vector as long as \code{nrow(x)} that has the "bias"
information for the features/genes tested (ie. vector of gene lengths).}

\item{method}{The method to use to calculate the unbiased category
enrichment scores}

\item{repcnt}{Number of random samples to be calculated when random sampling
is used. Ignored unless \code{method="Sampling"}.}

\item{use_genes_without_cat}{A boolean to indicate whether genes without a
categorie should still be used. For example, a large number of gene may
have no GO term annotated. If this option is set to FALSE, those genes
will be ignored in the calculation of p-values (default behaviour). If
this option is set to TRUE, then these genes will count towards the total
number of genes outside the category being tested.}

\item{do.conform}{By default \code{TRUE}: does some gymnastics to conform
the \code{gsd} to the \code{universe} vector. This should neber be set
to \code{FALSE}, but this parameter is here so that when this function
is called from the \code{\link{multiGSEA}} codepath, we do not have to
reconform the \code{GeneSetDb} object, because it has already been done.}

\item{active.only}{If \code{TRUE}, only "active" genesets are used}

\item{value}{The featureId types to extract from \code{gsd}}
}
\value{
A \code{data.table} of results, similar to goseq output.
}
\description{
Perform goseq Enrichment tests across a GeneSetDb.
}
