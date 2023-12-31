#' @include validateInputs.R
NULL

validate.inputs.roast <- .validate.inputs.full.design
validate.x.roast <- validate.X

#' Worker function to run roast from within a seas pipeline
#'
#' **This function is not meant to be called directly.** It should only be
#' called internally within [seas()].
#'
#' @noRd
#' @importFrom limma mroast
#' @importFrom edgeR mroast.DGEList
do.roast <- function(gsd, x, design, contrast=ncol(design),
                     gs.idxs=as.list(gsd, active.only=TRUE, value='x.idx'),
                     ...) {
  stopifnot(is.conformed(gsd, x))
  args <- list(...)
  call.args <- as.list(formals(limma::mroast.default))
  for (arg in intersect(names(args), names(call.args))) {
    call.args[[arg]] <- args[[arg]]
  }

  call.args[['y']] <- x
  call.args[['index']] <- gs.idxs
  call.args[['design']] <- design
  call.args[['contrast']] <- contrast
  call.args[['sort']] <- 'none'
  call.args[['...']] <- NULL
  ## earlier versions of edgeR::mroast was double-passing var.prior
  if (is(x, 'DGEList')) {
    ## var.prior and df.prior are set internally in edgeR::mroast.DGEList
    ## if we don't nuke them here, they will be passed in twice to limma::mroast
    ## and the call will error out
    call.args[['var.prior']] <- NULL
    call.args[['df.prior']] <- NULL
  }
  res <- do.call(mroast, call.args)
  setattr(res, 'rawresult', TRUE)
}

#' @noRd
mgres.roast <- function(res, gsd, ...) {
  if (!isTRUE(attr(res, 'rawresult'))) return(res)
  out <- cbind(geneSets(gsd, as.dt=TRUE)[, list(collection, name)], setDT(res))
  # silence R CMD check NOTEs
  NGenes <- FDR <- FDR.Mixed <- PValue.Mixed <- PValue <- NULL
  out[, NGenes := NULL]

  # result may not have an FDR column if we only tested on geneset
  # https://github.com/lianos/multiGSEA/issues/7
  if (is.null(out[["FDR"]])) out[, FDR := p.adjust(PValue)]
  if (is.null(out[["FDR.Mixed"]])) out[, FDR.Mixed := p.adjust(PValue.Mixed)]

  setnames(out,
           c('PValue', 'FDR', 'PValue.Mixed', 'FDR.Mixed'),
           c('pval', 'padj', 'pval.mixed', 'padj.mixed'))
}
