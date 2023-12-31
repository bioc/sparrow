#' Performs a plethora of set enrichment analyses over varied inputs.
#'
#' This is a wrapper function that delegates GSEA analyses to different
#' "workers", each of which implements the flavor of GSEA of your choosing.
#' The particular analyses that are performed are specified by the
#' `methods` argument, and these methods are fine tuned by passing their
#' arguments down through the `...` of this wrapper function.
#'
#' Set enrichment analyses can either be performed over an expression object,
#' which requires the specification of the experiment design and contrast of
#' interest, or over a set of features to rank (stored as a data.frame or
#' vector).
#'
#' Note that we are currently in the middle of a refactor to accept and fully
#' take advantage of `data.frame` as inputs for `x`, which will be used for
#' preranked type of GSEA methods. See the following issue for more details:
#' https://github.com/lianos/multiGSEA/issues/24
#'
#' The bulk of the GSEA methods currently available in this package come from
#' edgeR/limma, however others are included (and are being added), as well.
#' *GSEA Methods* and *GSEA Method Parameterization* sections for more details.
#'
#' In addition to performing GSEA, this function also internally orchestrates
#' a differential expression analysis, which can be tweaked by identifying
#' the parameters in the [calculateIndividualLogFC()] function, and
#' passing them down through `...` here. The results of the differential
#' expression analysis (ie. the [limma::topTable()]) are accessible by calling
#' the [logFC()] function on the [SparrowResult()] object returned from this
#' function call.
#'
#' **Please Note**: be sure to cite the original GSEA method when using
#' results generated from this function.
#'
#' @section GSEA Methods:
#' You can choose the methods you would like to run by providing a character
#' vector of GSEA method names to the \code{methods} parameter. Valid methods
#' you can select from include:
#'
#' - `"camera"`: from [limma::camera()] (*)
#' - `"cameraPR"`: from [limma::cameraPR()]
#' - `"ora"`: overrepresentation analysis optionally accounting for bias
#'    ([ora()]). This method is a wrapper function that makes the functionality
#'    in [limma::kegga()] available to an arbitrary GeneSetDb.
#' - `"roast"`: from [limma::roast()] (*)
#' - `"fry"`: from [limma::fry()] (*)
#' - `"romer"`: from [limma::romer()] (*)
#' - `"geneSetTest"`: from [limma::geneSetTest()]
#' - `"goseq"`: from [goseq::goseq()]
#' - `"fgsea"`: from [fgsea::fgsea()]
#'
#' Methods annotated with a `(*)` indicate that these methods require
#' a complete expression object, a valid design matrix, and a contrast
#' specification in order to run. These are all of the same things you need to
#' provide when performing a vanilla differential gene expression analysis.
#'
#' Methods missing a `(*)` can be run on a feature-named input vector
#' of gene level statistics which will be used for ranking (ie. a named vector
#' of logFC's or t-statistics for genes). They can also be run by providing
#' an expression, design, and contrast vector, and the appropriate statistics
#' vector will be generated internally from the t-statistics, p-values, or
#' log-fold-changes, depending on the value provided in the `score.by`
#' parameter.
#'
#' The worker functions that execute these GSEA methods are functions named
#' `do.METHOD` within this package. These functions are not meant to be executed
#' directly by the user, and are therefore not exported. Look at the respective
#' method's help page (ie. if you are running `"camera"`, look at the
#' [limma::camera()] help page for full details. The formal parameters that
#' these methods take can be passed to them via the `...` in this `seas()`
#' function.
#'
#' @section GSEA Method Parameterization:
#'
#' Each GSEA method can be tweaked via a custom set of parameters. We leave the
#' documentation of these parameters and how they affect their respective GSEA
#' methods to the documentation available in the packages where they are
#' defined. The `seas()` call simply has to pass these parameters down
#' into the `...` parameters here. The `seas` function will then pass these
#' along to their worker functions.
#'
#' **What happens when two different GSEA methods have parameters with the
#' same name?**
#'
#' Unfortunately you currently cannot provide different values for these
#' parameters. An upcoming version version of sparrow will support this
#' feature via slightly different calling semantics. This will also allow the
#' caller to call the same GSEA method with different parameterizations so that
#' even these can be compared against each other.
#'
#' @section Differential Gene Expression:
#'
#' When the `seas()` call is given an expression matrix, design, and
#' contrast, it will also internally orchestrate a gene level differential
#' expression analysis. Depending on the type of expression object passed in
#' via `x`, this function will guess on the best method to use for this
#' analysis.
#'
#' If `x` is a \code{DGEList}, then ensure that you have already called
#' [edgeR::estimateDisp()] on `x` and edgeR's quasilikelihood framework will be
#' used, otherwise we'll use limma (note that `x` can be an `EList` run through
#' `voom()`, `voomWithQuailityWeights()`, or when where you have leveraged
#' limma's [limma::duplicateCorrelation()] functionality, even.
#'
#' The parameters of this differential expression analysis can also be
#' customized. Please refer to the [calculateIndividualLogFC()] function for
#' more information. The `use.treat`, `feature.min.logFC`,
#' `feature.max.padj`, as well as the `...` parameters from this function are
#' passed down to that funciton.
#'
#' @export
#' @importFrom BiocParallel bplapply SerialParam bpparam
#'
#' @param x An object to run enrichment analyses over. This can be an
#'   ExpressoinSet-like object that you can differential expression over
#'   (for roast, fry, camera), a named (by feature_id) vector of scores to run
#'   ranked-based GSEA, a data.frame with feature_id's, ranks, scores, etc.
#' @param gsd The [GeneSetDb()] that defines the gene sets of interest.
#' @param methods A character vector indicating the GSEA methods you want to
#'   run. Refer to the GSEA Methods section for more details.
#'   If no methods are specified, only differential gene expression and geneset
#'   level statistics for the contrast are computed.
#' @param design A design matrix for the study
#' @param contrast The contrast of interest to analyze. This can be a column
#'   name of `design`, or a contrast vector which performs "coefficient
#'   arithmetic" over the columns of `design`. The `design` and `contrast`
#'   parameters are interpreted in *exactly* the same way as the same parameters
#'   in limma's [limma::camera()] and [limma::roast()] methods.
#' @param use.treat should we use limma/edgeR's "treat" functionality for the
#'   gene-level differential expression analysis?
#' @param feature.min.logFC The minimum logFC required for an individual
#'   feature (not geneset) to be considered differentialy expressed. Used in
#'   conjunction with `feature.max.padj` primarily for summarization
#'   of genesets (by [geneSetsStats()], but can also be used by GSEA methods
#'   that require differential expression calls at the individual feature level,
#'   like [goseq()].
#' @param feature.max.padj The maximum adjusted pvalue used to consider an
#'   individual feature (not geneset) to be differentially expressed. Used in
#'   conjunction with `feature.min.logFC`.
#' @param trim The amount to trim when calculated trimmed `t` and
#'   `logFC` statistics for each geneset. This is passed down to the
#'   [geneSetsStats()] function.
#' @param verbose make some noise during execution?
#' @param ... The arguments are passed down into
#'   [calculateIndividualLogFC()] and the various geneset analysis functions.
#' @param score.by This tells us how to rank the features after differential
#'   expression analysis when `x` is an expression container. It specifies the
#'   name of the column to use downstream of a differential expression analysis
#'   over `x`. If `x` is a data.frame that needs to be ranked, see `rank_by`.
#' @param rank_by Only works when `x` is a data.frame-like input. The name of a 
#'   column that should be used to rank the features in `x` for pre-ranked gsea
#'   tests like cameraPR or fgsea.  `rank_by` overrides `score.by`
#' @param rank_order Only used when `x` is a data.frame-like input. Specifies 
#'   how the features in `x` should be used to rank the features in `x` using 
#'   the `rank_by` column. Accepted values are:
#'   `"ordered"` (default) means that the rows in `x` are pre-ranked already.
#'   `"descendeing"`, and `"ascending"`. 
#' @param xmeta. A hack to support data.frame inputs for `x`. End users should
#'   not use this.
#' @param BPPARAM a *BiocParallel* parameter definition, like one generated from
#'   [BiocParallel::MulticoreParam()], or [BiocParallel::BatchtoolsParam()],
#'   for instance, which is passed down to [BiocParallel]::bplapply()]. Default
#'   is set to [BiocParallel::SerialParam()]
#' @return A [SparrowResult()] which holds the results of all the analyses
#'   specified in the `methods` parameter.
#'
#' @examples
#' vm <- exampleExpressionSet()
#' gdb <- exampleGeneSetDb()
#' mg <- seas(vm, gdb, c('camera', 'fry'),
#'            design = vm$design, contrast = 'tumor',
#'            # customzie camera parameter:
#'            inter.gene.cor = 0.04)
#' resultNames(mg)
#' res.camera <- result(mg, 'camera')
#' res.fry <- result(mg, 'fry')
#' res.all <- results(mg)
seas <- function(x, gsd, methods = NULL,
                 design = NULL, contrast = NULL, use.treat = FALSE,
                 feature.min.logFC = if (use.treat) log2(1.25) else 1,
                 feature.max.padj = 0.10, trim = 0.10, verbose = FALSE, ...,
                 score.by = c('t', 'logFC', 'pval'),
                 rank_by = NULL,
                 rank_order = c("ordered", "descending", "ascending"),
                 xmeta. = NULL, BPPARAM = BiocParallel::SerialParam()) {
  stopifnot(is(BPPARAM, 'BiocParallelParam'))
  if (!is(gsd, "GeneSetDb")) {
    gsd <- GeneSetDb(gsd, ...)
  }
  if (missing(methods) || length(methods) == 0) {
    methods <- "logFC"
  }

  # score.by was the original parameter used, and rank_by was introduced later
  # when we wanted to support data.frame inputs. This makes life difficult.
  score.by <- match.arg(score.by)
  if (test_string(rank_by)) {
    score.by <- rank_by
  }
  if (missing(rank_by) || is.null(rank_by)) {
    rank_by <- score.by
  }
  assert_string(score.by)
  assert_string(rank_by)
  if (score.by != rank_by) {
    stop("score.by and rank_by need to be reconsiled into one variable, but ",
         "for now their values must be the same")
  }

  # Supporting for data.frames is painful right now, and will be refactored
  # during a future release cycle.
  if (is.data.frame(x)) {
    rank_order <- match.arg(rank_order)
    assert_character(x[["feature_id"]])
    if (rank_order != "ordered" && (!test_string(rank_by) || ! test_numeric(x[[rank_by]]))) {
      msg <- paste(
        "data.frame inputs for `x` require that the `rank_by` parameter is the",
        "names a numeric colum in `x` that can be used to rank its rows.\n",
        "If your GSEA method does not require ranks (like 'ora'), the rankings",
        "will not be used, but you still need rank_by to point to a numeric",
        "column.\n This requirement will be fixed in a future version of",
        "sparrow")
      stop(msg)
    }

    if (rank_order != "ordered") {
      assert_numeric(x[[rank_by]])
      xo <- order(x[[rank_by]], decreasing = rank_order == "descending")
      x <- x[xo,,drop = FALSE]
    }
    xmeta. <- x
    x <- setNames(x[[rank_by]], x[["feature_id"]])
  }

  stopifnot(
    is.numeric(feature.min.logFC) && length(feature.min.logFC) == 1L,
    is.numeric(feature.max.padj) && length(feature.max.padj) == 1L,
    is.numeric(trim) && length(trim) == 1L)

  if (is.null(xmeta.) && !is.null(fdata(x))) {
    xmeta. <- fdata(x)
    xmeta.[["feature_id"]] <- rownames(x)
  }

  # ----------------------------------------------------------------------------
  # Argument sanity checking and input sanitization
  inputs <- validateInputs(x, design, contrast, methods, xmeta. = xmeta.,
                           require.x.rownames=TRUE, ...)

  x <- inputs[["x"]]
  design <- inputs[["design"]]
  contrast <- inputs[["contrast"]]
  xmeta. <- inputs[["xmeta."]]

  if (!is.conformed(gsd, x)) {
    gsd <- conform(gsd, x, ...)
  }

  # ----------------------------------------------------------------------------
  # Run the analyses
  # First calculate differential expression statistics, or wrap a pre-ranked
  # vector into a data.frame returned by an internal dge analysis
  treat.lfc <- if (use.treat) feature.min.logFC else NULL
  logFC <- calculateIndividualLogFC(x, design, contrast, treat.lfc = treat.lfc,
                                    verbose = verbose, ...,
                                    xmeta. = xmeta., as.dt = TRUE)
  test_type <- attr(logFC, "test_type")

  if (!is.logical(logFC[["significant"]])) {
    # If xmeta. was passed in, it may already have been defined
    logFC[, significant := {
      if (test_type == "anova" || !is.numeric(logFC)) {
        padj <= feature.max.padj
      } else {
        padj <= feature.max.padj & abs(logFC) >= feature.min.logFC
      }
    }]
  }

  # the 'logFC' method is just a pass through -- we don't call it if it was
  # provided
  methods <- setdiff(methods, "logFC")

  # Let's do this!
  results <- list()
  if (length(methods) > 0L) {
    # I'm being too clever here. The loop that calls the GSEA methods catches
    # errors thrown during iteration. I'm putting some code here to eat those
    # error so that the other GSEA methods that can finish.
    finished <- FALSE
    on.exit({
      if (!finished) {
        warning("An error in `seas` stopped it from finishing ...",
                immediate.=TRUE)
      }
    })

    ## Many methods create a geneset to rowname/index vector. Let's run it once
    ## here and pass it along
    gs.idxs <- as.list(gsd, active.only = TRUE, value = "x.idx")

    if (verbose) message("methods: ", paste(methods, collapse = ","))
    res1 <- bplapply(methods, function(method.) {
      if (verbose) message("... ", method.)
      tryCatch(mg.run(method., gsd, x, design, contrast, logFC, use.treat,
                      feature.min.logFC, feature.max.padj, verbose=verbose,
                      gs.idxs=gs.idxs,  score.by = score.by, ...),
               error=function(e) list(NULL))
    }, BPPARAM=BPPARAM)
    names(res1) <- methods

    failed <- sapply(res1, function(res) is.null(res[[1L]]))
    if (any(failed)) {
      warning("The following GSEA methods failed and are removed from the ",
              "downstream result: ",
              paste(names(res1)[failed], collapse=','), "\n")
      res1 <- res1[!failed]
    }

    results <- unlist(res1, recursive=FALSE)
    names(results) <- sub('\\.all$', '', names(results))
  }

  out <- .SparrowResult(gsd=gsd, results=results, logFC=logFC)
  gs.stats <- geneSetsStats(out, feature.min.logFC=feature.min.logFC,
                            feature.max.padj=feature.max.padj,
                            trim=trim, reannotate.significance = FALSE,
                            as.dt=TRUE)
  axe.gsd.cols <- setdiff(colnames(gs.stats), c('collection', 'name'))
  axe.gsd.cols <- intersect(axe.gsd.cols, colnames(out@gsd@table))
  new.table <- copy(out@gsd@table)
  ## Remove any columns in gs.stats that are already in the GeneSetDb@table
  ## (ie. if we got a GeneSetDb from a previous SparrowResult and we don't
  ## remove these columns, you will get thigns like mean.logFC.x and
  ## mean.logFC.y
  if (length(axe.gsd.cols)) {
    name <- NULL
    for (name in axe.gsd.cols) new.table[, c(name) := NULL]
  }
  out@gsd@table <- merge(new.table, gs.stats, by=key(new.table))
  finished <- TRUE
  out
}

#' Helper function that runs a single GSEA method
#'
#' this method insures that all results (even for single data.frames) are
#' returned in a list object. this allows for the goseq.all, goseq.up,
#' goseq.down hacks from a single goseq call
#'
#' @noRd
mg.run <- function(xmethod, gsd, x, design, contrast, logFC=NULL,
                   use.treat=TRUE, feature.min.logFC=log2(1.25),
                   feature.max.padj=0.10, verbose=FALSE, ...) {
  fn.name <- paste0('do.', xmethod)
  if (verbose) {
    message("... calling: ", fn.name)
  }

  fn <- getFunction(fn.name)
  res <- fn(gsd, x, design, contrast, logFC=logFC,
            use.treat=use.treat, feature.min.logFC=feature.min.logFC,
            feature.max.padj=feature.max.padj, verbose=verbose, ...)
  if (!isTRUE(attr(res, 'mgunlist', TRUE))) {
    res <- list(all=res)
  }
  out <- res
  if (verbose) {
    message("... ", fn.name, " finishd without error.")
  }
  out
}
