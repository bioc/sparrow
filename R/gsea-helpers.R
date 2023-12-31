#' Z-tranfsorm a vector of pvalues
#'
#' These values are useful for heatmap plotting.
#' TODO: Implement ztransformPvalues
#'
#' @noRd
#' @param x `numeric` vector of pvalues
#' @param logFC `numeric` vector as long as `x` that indicates the
#'   sign of the shift. This does not have to be the actual logFC of the
#'   geneset, as it is merely transformed to its `sign`.
#' @param alternative were these obtained from a two-sided or one-sided test?
#' @return `numeric` vector of the ztransformed pvalues in `x`.
ztransformPvalues <- function(x, logFC,
                              alternative=c('two.sided', 'less', 'greater')) {
  alternative <- match.arg(alternative)
  stopifnot(is.numeric(x) && all(x <= 1 & x >= 0))
  stopifnot(is.numeric(logFC))
  logFC <- sign(logFC)
  stop("ztransformPvalues not yet implemented, will export when done")
  ## shoot gsea pvalues through qnorm to get effect size, ie.
  ##
  ##   if logFC is positive: z = qnorm(1-(p/2))
  ##   if logFC is negative: z = qnorm(p)
  ##
  ## this puts you on the standard gaussian
  ##
  ## scale : -2 to +2 is not interesting: white
  ##
  ## qnorm(p/2) or qnorm(1-(p/2))
}
