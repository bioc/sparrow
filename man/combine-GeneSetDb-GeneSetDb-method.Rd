% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/GeneSetDb-methods.R
\name{combine,GeneSetDb,GeneSetDb-method}
\alias{combine,GeneSetDb,GeneSetDb-method}
\title{Combines two GeneSetDb objects together}
\usage{
\S4method{combine}{GeneSetDb,GeneSetDb}(x, y, ...)
}
\arguments{
\item{x}{a GeneSetDb object}

\item{y}{a GeneSetDb object}

\item{...}{more things}
}
\value{
a new GeneSetDb that contains all genesets from \code{x} and \code{y}
}
\description{
Combines two GeneSetDb objects together
}
\examples{
gdb1 <- exampleGeneSetDb()
gdb2 <- GeneSetDb(exampleGeneSetDF())
gdb <- combine(gdb1, gdb2)
}
