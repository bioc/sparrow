#' Generates single sample gene set scores across a datasets by many methods
#'
#' It is common to assess the activity of a gene set in a given sample. There
#' are many ways to do that, and this method is analogous to the
#' [seas()] function in that it enables the user to run a multitude of
#' single-sample-gene-set-scoring algorithms over a target expression matrix
#' using a [GeneSetDb()] object.
#'
#' Please refer to the "Generating Single Sample Gene Set Scores" of the
#' sparrow vignette for further exposition.
#'
#' @section Single Sample Scoring Methods:
#' The following `methods` are currenly provided.
#'
#' * `"ewm"`: The [eigenWeightedMean()] calculates the fraction each gene
#'    contributes to a pre-specified principal component. These contributions
#'    act as weights over each gene, which are then used in a simple weighted
#'    mean calculation over all the genes in the geneset per sample. This is
#'    similar, in spirit, to the svd/gsdecon method (ie. `method = "gsd"``)
#'    You can use this method to perform an "eigenweighted" zscore by setting
#'    `unscale` and `uncenter` to `FALSE`.
#'    `"ewz"`: with `unscale` and `uncenter` set to `FALSE`.
#' * `"gsd"`: This method was first introduced by Jason Hackney in
#'    [doi:10.1038/ng.3520](https://doi.org/10.1038/ng.3520). Please refer to
#'    the [gsdScore()] function for more information.
#' * `"ssgsea"`: Using ssGSEA as implemented in the GSVA package.
#' * `"zscore"`: The features in the expression matrix are rowwise z transformed.
#'    The gene set level score is then calculated by adding up the zscores for
#'    the genes in the gene set, then dividing that number by either the the
#'    size (or its sqaure root (default)) of the gene set.
#' * `"mean"`: Simply take the mean of the values from the expression matrix
#'    that are in the gene set. Right or wrong, sometimes you just want the mean
#'    without transforming the data.
#' * `"gsva"`: The gsva method of GSVA package.
#' * `"plage"`: Using "plage" as implemented in the GSVA package
#'
#' @export
#' @param gdb A GeneSetDb
#' @param y An expression matrix to score genesets against
#' @param methods A character vector that enumerates the scoring methods you
#'   want to run over the samples. Please reference the "Single Sample Scoring
#'   Methods" section for more information.
#' @param as.matrix Return results as a list of matrices instead of a melted
#'   data.frame? Defaults to `FALSE`.
#' @param drop.sd Genes with a standard deviation across columns in \code{y}
#'   that is less than this value will be dropped.
#' @param drop.unconformed When `TRUE`, genes in `y` that are not found in
#'   `gdb` are removed from the expression container. You may want to set this
#'   to `TRUE` when `y` is very large until better sparse matrix support is
#'   injected. This will change the scores for gsva and ssGSEA, though.
#'   Default is `FALSE`.
#' @param verbose make some noise? Defaults to `FALSE`.
#' @param recenter,rescale If `TRUE`, the scores computed by each method
#'   are centered and scaled using the `scale` function. These variables
#'   correspond to the `center` and `scale` parameters in the
#'   `scale` function. Defaults to `FALSE`.
#' @param ... these parameters are passed down into the the individual single
#'   sample scoring funcitons to customize them further.
#' @template asdt-param
#' @return A long data.frame with sample_id,method,score values per row. If
#'   `as.matrix=TRUE`, a matrix with as many rows as `geneSets(gdb)`
#'   and as many columns as `ncol(x)`
#'
#' @examples
#' gdb <- exampleGeneSetDb()
#' vm <- exampleExpressionSet()
#' scores <- scoreSingleSamples(
#'   gdb, vm, methods = c("ewm", "gsva", "zscore"),
#'   center = TRUE, scale = TRUE, ssgsea.norm = TRUE, as.dt = TRUE)
#'
#' sw <- data.table::dcast(scores, name + sample_id ~ method, value.var='score')
#'
#' \donttest{
#' corplot(
#'   sw[, c("ewm", "gsva", "zscore")],
#'   title = "Single Sample Score Comparison")
#' }
#'
#' zs <- scoreSingleSamples(
#'   gdb, vm, methods = c('ewm', 'ewz', 'zscore'), summary = "mean",
#'   center = TRUE, scale = TRUE, uncenter = FALSE, unscale = FALSE,
#'   as.dt = TRUE)
#' zw <- data.table::dcast(zs, name + sample_id ~ method, value.var='score')
#'
#' \donttest{
#'   corplot(zw[, c("ewm", "ewz", "zscore")], title = "EW zscores")
#' }
scoreSingleSamples <- function(gdb, y, methods = "ewm", as.matrix = FALSE,
                               drop.sd = 1e-4, drop.unconformed = FALSE,
                               verbose = FALSE, recenter = FALSE,
                               rescale = FALSE, ...,
                               as.dt = FALSE) {
  methods <- tolower(methods)
  if (as.matrix && length(methods) > 1L) {
    stop("Can only score with one method if returning a matrix")
  }
  bad.methods <- setdiff(methods, names(gs.score.map))
  if (length(bad.methods)) {
    stop("Uknown geneset scoring methods: ",
         paste(bad.methods, collapse=','),
         "\nValid methods are: ",
         paste(names(gs.score.map), collapse=','))
  }
  if (!is(gdb, "GeneSetDb")) gdb <- GeneSetDb(gdb, ...)
  assert_class(gdb, "GeneSetDb")
  gdb <- conform(gdb, y, ...)

  # We used to filter down y.all to only include rows that appeared as features
  # in the in the GeneSetDb object, however this will change the scoring output
  # of some methods, namely *all* of the ones in GSVA (gsva, ssgsea, plage).
  if (isTRUE(drop.unconformed)) {
    y.all <- as_matrix(y, gdb)
  } else {
    y.all <- as_matrix(y)
  }

  if (is(y.all, "sparseMatrix")) {
    # Can't get everything to be transparent with sparse matrices just yet
    # If you are scoring single cell data with a gdb that covers a large
    # proportion of your feature space, you might be sorry right about now.
    y.all <- as.matrix(y.all)
  }
  sds <- DelayedMatrixStats::rowSds(y.all)
  sd0 <- sds < drop.sd
  y <- y.all[!sd0,,drop=FALSE]
  if (any(sd0)) {
    warning(sum(sd0), " row(s) removed from expression object (y) due to 0sd")
  }

  gdb <- conform(gdb, y, ...)

  # y.slim <- as_matrix(y, gdb) # subsets y down to features in gdb

  if (is.null(colnames(y))) {
    colnames(y) <- if (ncol(y) == 1) 'score' else paste0('scores', seq(ncol(y)))
  }

  gs.names <- encode_gskey(geneSets(gdb))
  gs.idxs <- as.list(gdb, active.only=TRUE, value='x.idx')

  scores <- sapply(methods, function(method) {
    fn <- gs.score.map[[method]]
    out <- fn(gdb, y, method = method, as.matrix = as.matrix, verbose = verbose,
              gs.idxs = gs.idxs, ...)
    rownames(out) <- gs.names
    if (!isFALSE(recenter) || !isFALSE(rescale)) {
      out <- scale_rows(out, center = recenter, scale = rescale)
    }
    if (!as.matrix) {
      out <- melt.gs.scores(gdb, out)
      out$method <- method
    }
    out
  }, simplify=FALSE)

  if (length(scores) == 1L) {
    scores <- scores[[1L]]
  } else {
    if (!as.matrix) {
      scores <- rbindlist(scores)
    }
  }

  if (!as.matrix && !as.dt) setDF(scores)

  # I'm not a bad person, I just want to keep this S3 so end users can
  # use the data.frame results in dplyr chains.
  # if (is.matrix(scores)) {
  #   class(scores) <- c('sss_matrix', class(scores))
  # } else {
  #   class(scores) <- c('sss_frame', class(scores))
  # }

  scores
}

#' Melts the geneset matrix scores from the do.scoreSingleSamples.* methods
#'
#' @noRd
#'
#' @param gdb A [GeneSetDb()] used for scoring
#' @param scores The `matrix` of geneset scores returned from the various
#'   `do.scoreSingleSamples.*` methods.
#' @param a melted `data.table` of scores
melt.gs.scores <- function(gdb, scores) {
  out <- cbind(geneSets(gdb, as.dt=TRUE)[, list(collection, name, n)], scores)
  out <- data.table::melt.data.table(out, c("collection", "name", "n"),
                                     variable.name = "sample_id",
                                     value.name='score')
  # handle non std eval NOTE in R CMD check when using `:=` data.table mojo
  sample_id <- NULL
  out[, sample_id := as.character(sample_id)]
}

#' @noRd
#'
#' @param zsummary use `"sqrt"` in denominator of zscores to stabilize the
#' variance of the mean, cf. Lee, E., et al. Inferring pathway activity toward
#' precise disease classification. PLoS Comput. Biol. 4, e1000217 (2008).
do.scoreSingleSamples.zscore <- function(gdb, y, zsummary=c('mean', 'sqrt'),
                                         trim=0, gs.idxs=NULL, do.scale=TRUE,
                                         ...) {
  stopifnot(is.conformed(gdb, y))
  zsummary <- match.arg(zsummary)

  score.fn <- if (zsummary == 'mean') {
    function(vals) mean(vals, trim=trim, na.rm=TRUE)
  } else {
    function(vals) {
      keep <- !is.na(vals)
      sum(vals[keep]) / sqrt(sum(keep))
    }
  }

  if (is.null(gs.idxs)) gs.idxs <- as.list(gdb, active.only=TRUE, value='x.idx')
  if (do.scale) y <- t(scale(t(y)))

  scores <- sapply(seq_len(ncol(y)), function(y.col) {
    col.vals <- y[, y.col]
    sapply(seq(gs.idxs), function(gs.idx) {
      vidx <- gs.idxs[[gs.idx]]
      score.fn(col.vals[vidx])
    })
  })
  if (!is.matrix(scores)) {
    ## This happens when the GeneSetDb had only one signature. Turn it into
    ## a matrix because things upstream expect matrices as outputs of these
    ## do.* functions.
    scores <- matrix(scores, nrow=1L)
  }
  colnames(scores) <- colnames(y)
  scores
}

#' Just take the average of the raw scores from the expression matrix
#'
#' Right or wrong, sometimes you want this (most often you want mean Z, though)
#'
#' @noRd
do.scoreSingleSamples.mean <- function(gdb, y, gs.idxs=NULL, ...) {
  do.scoreSingleSamples.zscore(gdb, y, zsummary='mean',
                               trim=0, gs.idxs=gs.idxs, do.scale=FALSE)
}

# #' @importFrom GSVA gsva
# #' @noRd
# do.scoreSingleSamples.gsva <- function(gdb, y, method, as.matrix=FALSE,
#                                        parallel.sz=1, ssgsea.norm=FALSE,
#                                        gs.idxs=NULL, ...) {
#   if (is.null(gs.idxs)) {
#     gs.idxs <- as.list(gdb, active.only=TRUE, value='x.idx')
#   }
#   idxs <- lapply(gs.idxs, function(i) rownames(y)[i])
#   f <- formals(GSVA:::.gsva)
#   args <- list(...)
#   ## I want to explicity show that we are setting parallel.sz to 4 here, since
#   ## it will defalut to "Infinity" (all your cores are belong to GSVA)
#   args$parallel.sz <- parallel.sz
#   args$ssgsea.norm <- ssgsea.norm
#   take <- intersect(names(args), names(f))
#   gargs <- list(expr=y, gset.idx.list=idxs, method=method)
#   gargs <- c(gargs, args[take])
#
#   gres <- do.call(gsva, gargs)
#   gres
# }

#' This can handle method = "gsva", "ssgsea", and "plage"
#' @noRd
do.scoreSingleSamples.gsva <- function(
    gdb, y, method, kcdf = c("Gaussian", "Poisson", "none"),
    abs.ranking = FALSE, mx.diff = TRUE, tau = 1, alpha = 0.25,
    ssgsea.norm = TRUE, gs.idxs = NULL, verbose = FALSE, ...,
    BPPARAM = BiocParallel::SerialParam(progressbar = verbose)) {
  reqpkg("GSVA")
  method <- match.arg(method, c("gsva", "ssgsea", "plage"))
  kcdf <- match.arg(kcdf)
  if (is.null(tau)) tau <- switch(method, gsva = 1, ssgsea = 0.25, NA)

  # gsva requires that the geneset list is defined using the rownames
  # of the expression matrix
  if (is.null(gs.idxs)) {
    gs.idxs <- as.list(gdb, active.only = TRUE, value = "x.idx")
  }
  idxs <- lapply(gs.idxs, function(i) rownames(y)[i])
  
  params <- switch(
    method,
    gsva = GSVA::gsvaParam(y, idxs, maxDiff = mx.diff, kcdf = kcdf,
                           tau = tau, absRanking = abs.ranking),
    ssgsea = GSVA::ssgseaParam(y, idxs, alpha = alpha, normalize = ssgsea.norm),
    plage = GSVA::plageParam(y, idxs))

  # GSVA::gsva(y, idxs, method = method, kcdf = kcdf,
  #            abs.ranking = abs.ranking, parallel.sz = parallel.sz,
  #            mx.diff = mx.diff, tau = tau, ssgsea.norm = ssgsea.norm,
  #            verbose = verbose)
  GSVA::gsva(params, verbose = verbose, BPPARAM = BPPARAM)
}



#' Normalize a vector of ssGSEA scores in the ssGSEA way.
#'
#' ssGSEA normalization (as implemented in GSVA (ssgsea.norm)) normalizes the
#' individual scores based on ALL scores calculated across samples AND
#' genesets. It does NOTE normalize the scores within each geneset
#' independantly of the others.
#'
#' This method is an internal utilit function and not exported on purpose
#'
#' @param x a `numeric` vector of ssGSEA scores for a single signature
#' @param bounds the maximum and minimum scores obvserved used to normalize
#'   against.
#' @return normalized \code{numeric} vector of \code{x}
ssGSEA.normalize <- function(x, bounds=range(x)) {
  ## apply(es, 2, function(x, es) x / (range(es)[2] - range(es)[1]), es)
  stopifnot(length(bounds) == 2L)
  max.b <- max(bounds)
  min.b <- min(bounds)
  stopifnot(all(x <= max.b) && all(x >= min.b))
  x / (max.b - min.b)
}

#' A no dependency call to GSDecon-like eigengene scoring
#'
#' @noRd
do.scoreSingleSamples.gsd <- function(gdb, y, as.matrix=FALSE, center=TRUE,
                                      scale=TRUE, uncenter=center,
                                      unscale=scale, gs.idxs=NULL, ...) {
  stopifnot(is.matrix(y))
  stopifnot(is.conformed(gdb, y))

  if (is.null(gs.idxs)) {
    gs.idxs <- as.list(gdb, active.only=TRUE, value='x.idx')
  }

  scores <- lapply(gs.idxs, function(idxs) {
    gsdScore(y[idxs,,drop = FALSE], center=center, scale=scale, uncenter=uncenter,
             unscale=unscale)
  })

  out <- t(sapply(scores, '[[', 'score'))
  rownames(out) <- names(gs.idxs)
  colnames(out) <- colnames(y)
  out
}

#' @noRd
do.scoreSingleSamples.eigenWeightedMean <- function(gdb, y, eigengene = 1L,
                                                    center = TRUE, scale = TRUE,
                                                    uncenter=center,
                                                    unscale=scale,
                                                    weights=NULL,
                                                    normalize=FALSE,
                                                    as.matrix=FALSE,
                                                    gs.idxs=NULL, ...) {
  stopifnot(is.matrix(y))
  stopifnot(is.conformed(gdb, y))

  if (is.null(gs.idxs)) {
    gs.idxs <- as.list(gdb, active.only=TRUE, value='x.idx')
  }

  scores <- sapply(gs.idxs, function(idxs) {
    eigenWeightedMean(y[idxs,,drop = FALSE], center=center, scale=scale,
                      uncenter=uncenter, unscale=unscale, weights=weights,
                      normalize=normalize, all.x=y)$score
  })

  out <- t(scores)
  rownames(out) <- names(gs.idxs)
  colnames(out) <- colnames(y)
  out
}

#' @noRd
do.scoreSingleSamples.ewzscore <- function(gdb, y, weights = NULL,
                                           eigengene = 1L,
                                           center = TRUE, scale = TRUE,
                                           uncenter=FALSE,
                                           unscale=FALSE,
                                           normalize=FALSE,
                                           as.matrix=FALSE,
                                           gs.idxs=NULL, ...) {
  do.scoreSingleSamples.eigenWeightedMean(
    gdb, y, eigengene = eigengene, center = TRUE, scale = TRUE,
    uncenter = FALSE, unscale = FALSE, weights = weights, normalize = normalize,
    as.matrix = as.matrix, gs.idxs = gs.idxs, ...)
}

#' An internal map of abbreviated scoring method names to functions
#' @noRd
gs.score.map <- list(
  zscore = do.scoreSingleSamples.zscore,
  ewz    = do.scoreSingleSamples.ewzscore,
  gsva   = do.scoreSingleSamples.gsva,
  plage  = do.scoreSingleSamples.gsva,
  ssgsea = do.scoreSingleSamples.gsva,
  svd    = do.scoreSingleSamples.gsd,
  gsd    = do.scoreSingleSamples.gsd,
  ewm    = do.scoreSingleSamples.eigenWeightedMean,
  mean   = do.scoreSingleSamples.mean)
