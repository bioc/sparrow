##' @include validateInputs.R
NULL

validate.inputs.romer <- .validate.inputs.full.design

## validate.x.romer <- validate.DGEList

validate.x.romer <- function(x, xmeta. = NULL, ...) {
  if (isTRUE(is(x, 'DGEList'))) {
    if (!is.numeric(x$common.dispersion)) {
      return("dispersion is not estimated, minimally call estimateDisp(x)")
    }
  } else if (is(x, 'EList')) {
    if (is.matrix(x$weights)) {
      ## This is coming from voom?
      warning("x has $weights. romer hasn't been implemented for voom",
              immediate.=TRUE)
    }
  } else if (!is.matrix(x)) {
    return("romer only works with DGEList, EList, or matrix for x")
  }
  return(TRUE)
}

#' Worker function to run romer from within a sparrow::seas pipeline
#'
#' Note that romer works on a DGEList or a "normal" EList, ie. it has not
#' been updated to work with an \code{EList} with a \code{$weights} matrix,
#' and therefore doesn't work with a voom'd dataset.
#'
#' **This function is not meant to be called directly.** It should only be
#' called internally within [seas()].
#'
#' @noRd
#' @importFrom limma romer
#' @importFrom edgeR romer.DGEList
do.romer <- function(gsd, x, design, contrast=ncol(design),
                     gs.idxs = as.list(gsd, active.only = TRUE, value = "x.idx"),
                     ...) {
  stopifnot(is.conformed(gsd, x))
  args <- list(...)
  call.args <- as.list(formals(limma::romer.default))
  for (arg in intersect(names(args), names(call.args))) {
    call.args[[arg]] <- args[[arg]]
  }

  call.args[['y']] <- x
  call.args[['index']] <- gs.idxs
  call.args[['design']] <- design
  call.args[['contrast']] <- contrast
  call.args[["..."]] <- NULL

  res <- do.call(romer, call.args)
  ## returns a matrix(!) with the following columns
  ## "NGenes", "Up" (pvalue), "Down" (pvalue), "Mixed" (pvalue)
  setattr(res, 'rawresult', TRUE)
}

# this Mixed column becomes the pval
mgres.romer <- function(res, gsd, ...) {
  if (!isTRUE(attr(res, 'rawresult'))) return(res)
  ## check gsnames matches to geneSets()
  # gsnames <- sub('.*;;', '', rownames(res))
  gs.tuple <- split_gskey(rownames(res))
  gsnames <- gs.tuple$name
  gs <- geneSets(gsd, as.dt=TRUE)[, list(collection, name)]
  kosher <- length(gsnames) == nrow(gs) && all(gsnames == gs$name)
  if (!kosher) {
    stop("genesets from romer do not match geneSets(gdb)")
  }

  out <- cbind(gs, as.data.table(res))
  ## silence R CMD check NOTEs
  NGenes <- padj <- padj.up <- padj.down <- pval.up <- pval.down <- NULL

  out[, NGenes := NULL]

  setnames(out,
           c('Up', 'Down', 'Mixed'),
           c('pval.up', 'pval.down', 'pval'))
  ## silence no visible binding note
  out[, padj := p.adjust(pval)]
  out[, padj.up := p.adjust(pval.up)]
  out[, padj.down := p.adjust(pval.down)]

  out
}
