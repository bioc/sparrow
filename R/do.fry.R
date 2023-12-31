##' @include validateInputs.R
NULL

validate.inputs.fry <- .validate.inputs.full.design
validate.x.fry <- function(x, xmeta., ...) {
  ## This is not defined for DGEList yet
  if (is(x, 'DGEList') && packageVersion('edgeR') < '3.14') {
    warning("fry is not implemented for a DGEList yet", immediate.=TRUE)
    return(FALSE)
  }
  validate.X(x, xmeta.)
}

#' Worker function to run fry from within a seas pipeline
#'
#' **This function is not meant to be called directly.** It should only be
#' called internally within [seas()].
#'
#' @noRd
#' @importFrom limma fry
#' @importFrom edgeR fry.DGEList
do.fry <- function(gsd, x, design, contrast=ncol(design),
                   gs.idxs=as.list(gsd, active.only=TRUE, value='x.idx'), ...) {
  ## This function was defined in limma v3.23.13 in April 2015
  ## ------------------------------------------------------------------------
  ## r102075 | smyth@wehi.edu.au | 2015-04-07 22:56:02 -0700 (Tue, 07 Apr 2015)
  if (packageVersion('limma') < '3.23.13') {
    stop("fry not defined until limma 3.23.13")
  }
  stopifnot(is.conformed(gsd, x))
  args <- list(...)
  call.args <- as.list(formals(limma::fry.default))
  for (arg in intersect(names(args), names(call.args))) {
    call.args[[arg]] <- args[[arg]]
  }

  add.dummy <- length(gs.idxs) == 1
  dummy.gs <- 'zYxWvUt'
  if (add.dummy) {
    gs.idxs[[dummy.gs]] <- sample(nrow(x), 3, replace=TRUE)
  }

  call.args[['y']] <- x
  call.args[['index']] <- gs.idxs
  call.args[['design']] <- design
  call.args[['contrast']] <- contrast
  call.args[['sort']] <- FALSE
  call.args[['...']] <- NULL

  ## There is a bug in edgeR::fry.DGEList that double passes the standardize
  ## argument if it is passed in via `...`, so remove call.args$standardize
  ## here. The bug exists in v3.17.1, and was reported to Gordon on 11/3/2016
  if (is(x, 'DGEList')) {
    call.args[['standardize']] <- NULL
  }

  res <- do.call(limma::fry, call.args)
  if (add.dummy) res <- res[rownames(res) != dummy.gs,,drop = FALSE]
  setattr(res, 'rawresult', TRUE)
}

mgres.fry <- function(res, gsd, ...) {
  if (!isTRUE(attr(res, 'rawresult'))) return(res)
  out <- cbind(
    geneSets(gsd, as.dt=TRUE)[, list(collection, name)],
    as.data.table(res))
  # silence R CMD check NOTEs
  NGenes <- FDR <- FDR.Mixed <- PValue.Mixed <- PValue <- NULL
  out[, NGenes := NULL]

  # result may not have an FDR column if we only tested on geneset
  # https://github.com/lianos/multiGSEA/issues/7
  if (is.null(out[["FDR"]])) out[, FDR := p.adjust(PValue)]
  if (is.null(out[["FDR.Mixed"]])) out[, FDR.Mixed := p.adjust(PValue.Mixed)]

  rcols <- c(PValue='pval', FDR='padj', PValue.Mixed='pval.mixed',
             FDR.Mixed='padj.mixed')
  rcols <- rcols[names(rcols) %in% names(out)]
  setnames(out, names(rcols), rcols)
}
