% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/GeneSetDb-methods.R
\name{conversion}
\alias{conversion}
\alias{as.data.frame.GeneSetDb}
\alias{as.data.frame}
\alias{as.list}
\alias{as.list.GeneSetDb}
\title{Convert a GeneSetDb to other formats.}
\usage{
\method{as.data.frame}{GeneSetDb}(x, value = c("featureId", "x.id", "x.idx"),
  active.only = is.conformed(x), ...)

\method{as.list}{GeneSetDb}(x, value = c("featureId", "x.id", "x.idx"),
  active.only = is.conformed(x), nested = FALSE, ...)
}
\arguments{
\item{x}{A \code{GeneSetDb} object}

\item{value}{The value type to export for the feature ids}

\item{active.only}{If the \code{GeneSetDb} is conformed, do you want to only
return the features that match target and are "active"?}

\item{...}{nothing}
}
\value{
a converted \code{GeneSetDb}
}
\description{
As awesome as a GeneSetDb is, you might find a time when you'll need your
gene set information in an other format. To do that, we provide the
following functions:

\enumerate{
  \item{\code{as.data.frame}}{
    Perhaps the most natural format to convert to in order to save locally
    an examine outside of Bioconductor's GSEA universe, but not many other
    tools accet gene set definitions in this way
  }
  \item{\code{as.list}}{
    A named list of feature identifiers. This is the format that many of
    the limma gene set testing methods use
  }
  \item{\code{as(gdb, 'GeneSetCollection')}}{
    The \code{\link[GSEABase]{GeneSetCollection}} class.
  }
}

The \code{as.*} functions accept a \code{value} parameter which indicates
the type of IDs you want to export in the conversion. The following choices
are available:

\enumerate{
  \item{\code{"featureId"}}{
    The ID used as originally entered into the \code{GeneSetDb}
  }
  \item{\code{"x.idx"}}{
    Only valid if the GeneSetDb \code{x} has been \code{conform}-ed to
    an expession container. This option will export the features as the
    integer rows of the expression container.
  }
  \item{\code{"x.id"}}{
    Only valid if the GeneSetDb \code{x} has been \code{conform}-ed. The
    target expression container might use feature identifiers that are
    different than what is in the GeneSetDb. If an active featureMap is
    set on the GeneSetDb, this will convert the original feature identifiers
    into a different target space (entrez to ensembl, for instance). Using
    this option, the features will be provided in the target space.
  }
}
}
\examples{
es <- exampleExpressionSet()
gdb <- conform(exampleGeneSetDb(), es)
gdf <- as.data.frame(gdb)
gdfi <- as.data.frame(gdb, 'x.idx')
gdl <- as.list(gdb)
}