% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/plots-corplot.R
\name{corplot}
\alias{corplot}
\title{Plots the correlation among the columns of a numeric matrix.}
\usage{
corplot(
  E,
  title,
  cluster = FALSE,
  col.point = "#00000066",
  diag.distro = TRUE,
  smooth.scatter = nrow(E) > 400,
  max.cex.cor = NULL,
  ...
)
}
\arguments{
\item{E}{the matrix used to plot a pairs correlation plot. The vectors used
to assess all pairwise correlation should be \emph{in the columns} of the
matrix.}

\item{title}{The title of the plot}

\item{cluster}{\code{logical} indicating whether or not to shuffle genes
around into some clustering.}

\item{col.point}{the color of the points in the scatterplots}

\item{diag.distro}{show the distribution of values on the diagnols?}

\item{smooth.scatter}{boolean to indicate wether to use a normal scatter, or
a \code{\link[graphics:smoothScatter]{graphics::smoothScatter()}}. Defaults to \code{TRUE} if \code{nrow(E) > 400}}

\item{max.cex.cor}{the numeric value defining the maximum text size (cor) in the correlation panel.
By default there is no limit on the maximum text size and the text size is calculated with \code{0.8 / strwidth(text)}.
With \code{max.cex.cor} defined the text size is calculated as \code{min(0.8 / strwidth(text), max.cex.cor)}.}

\item{...}{pass through arguments to internal panel functions}
}
\value{
nothing, just creates the plot
}
\description{
We assume that this is a sample x gene expression matrix, but it can
(of course) be any numeric matrix of your choosing. The column names appear
in the main diagonal of the plot. Note that you might prefer the corrplot
package for similar functionality, and this functionality is intentionally
named different from that..
}
\details{
TODO: Add with.signature parameter to allow a box to plot the signature
score of all genes in E.
}
\examples{
x <- matrix(rnorm(1000), ncol=5)
corplot(x)
}
\seealso{
The \href{http://cran.r-project.org/package=corrplot}{corrplot} package
}
