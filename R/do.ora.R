#' @include validateInputs.R
NULL

validate.x.ora <- validate.X
validate.inputs.ora <- function(x, design, contrast, feature.bias,
                                xmeta. = NULL, ...) {
  if (!is.data.frame(xmeta.)) {
    default <- .validate.inputs.full.design(x, design, contrast)
    if (length(default)) {
      return(default)
    }
  }

  ## Ensure that caller provides a named feature.bias vector
  errs <- list()
  if (missing(feature.bias) || is.null(feature.bias)) {
    # This is actually OK, a normal enrichment will be run w/ no bias
  } else {
    if (is.character(feature.bias)) {
      if (!is.data.frame(xmeta.) || !is.numeric(xmeta.[[feature.bias]])) {
        errs <- c(
          errs,
          paste("when feature.bias is a string, xmeta. needs to be a ",
                "data.frame with a numeric column named `feature.bias`"))
        return(errs)
      }
      feature.bias <- setNames(xmeta.[[feature.bias]], xmeta.[["feature_id"]])
    }

    if (!is.numeric(feature.bias)) {
      errs <- 'feature.bias must be a numeric vector'
    }
    if (!all(rownames(x) %in% names(feature.bias))) {
      errs <- c(errs, 'some rownames(x) not in names(feature.bias)')
    }
  }

  return(errs)
}


#' This is a generic wrapper around limma::kegga to perform "biased enrichment"
#'
#' This, in principle, works similarly to goseq but uses [limma::kegga()] as its
#' engine. If you don't want to calculate any type of biased enrichment, then
#' explicitly set feature.bias and prior.prob to `NULL`.
#'
#' Running goseq would sometimes throw errors in the `makespline` call from
#' [goseq::nullp()], so I jumped over to this given this insight:
#' https://support.bioconductor.org/p/65789/#65914
#'
#' @noRd
#'
#' @param feature.bias we will try to extract the average expression of the
#'   gene as teh default bias, but you can send in gene length, or
#'   what-have-you
do.ora <- function(gsd, x, design, contrast = ncol(design),
                   feature.bias = "AveExpr",
                   restrict.universe = FALSE,
                   selected = "significant", groups = "direction",
                   use.treat = FALSE,
                   feature.min.logFC = if (use.treat) log2(1.25) else 1,
                   feature.max.padj = 0.10, logFC = NULL, ...) {
  # 1. Specify up and down genes as a list of identifiers:
  #      list(Up = sigup, Down = sigdown)
  # 2a. Process feature.bias parameter so that it is a numeric bias vector
  # 2b. Pass feature.bias into .calc_prior_prob
  # 2c. Pass 2b into kegga.default(covariate = NULL, prior.prob = 2b)
  #
  # 3. if there are no degenes, do not run anything and set outgoing results
  #    with pvals hammered to 1.

  # handle non std eval NOTE in R CMD check when using `:=` mojo
  Pathway <- n.drawn <- pval <- significant <- NULL

  stopifnot(is.conformed(gsd, x))
  # stop("testing graceful method failure in seas call")
  if (is.null(logFC)) {
    treat.lfc <- if (use.treat) feature.min.logFC else NULL
    logFC <- calculateIndividualLogFC(x, design, contrast, treat.lfc=treat.lfc,
                                      ..., as.dt=TRUE)
    logFC[[selected]] <-
      logFC[["padj"]] <= feature.max.padj &
      abs(logFC[["logFC"]]) >= feature.min.logFC
  }
  is.logFC.like(logFC, x, as.error=TRUE)
  logFC <- setDT(copy(logFC))
  if (!is.logical(logFC[[selected]])) {
    warning("logical column to identify enriched genes not found: ", selected,
            "setting `significant` column manually")

  }
  # if (is.null(logFC[["significant"]])) {
  #   logFC[, significant := {
  #     padj <= feature.max.padj & abs(logFC) >= feature.min.logFC
  #   }]
  # }

  ttype <- attr(logFC, "test_type")
  add.dir <- isTRUE(groups == "direction") &&
    isTRUE(ttype == "ttest") &&
    !is.character(logFC[["direction"]]) &&
    is.numeric(logFC[["logFC"]])
  if (add.dir) {
    logFC[["direction"]] <- ifelse(logFC[["logFC"]] > 0, "up", "down")
  }
  if (isTRUE(ttype == "anova") && isTRUE(groups == "direction")) {
    groups <- NULL
  }

  if (is.character(groups) && !is.character(logFC[[groups]])) {
    warning("`groups' column not found within do.ora")
    groups <- NULL
  }

  res <- ora(logFC, gsd, selected = selected,
             groups = groups,
             feature.bias = feature.bias,
             restrict.universe = restrict.universe,
             as.dt = TRUE)

  base <- res[, list(Pathway, n = N)]
  groups <- attr(res, "groups")
  if (is.null(groups)) groups <- "all"

  out <- sapply(groups, function(group) {
    grp <- copy(base)
    grp[, n.drawn := res[[group]]]
    grp[, pval := res[[paste0("P.", group)]]]
    setattr(grp, "rawresult", TRUE)
    grp
  }, simplify = FALSE)

  if (length(out) == 1L) {
    out <- out[[1L]]
  } else {
    setattr(out, 'mgunlist', TRUE)
  }

  out
}

mgres.ora <- function(res, gsd, ...) {
  # silence R CMD check NOTEs
  Pathway <- padj <- idx <- NULL
  if (!isTRUE(attr(res, "rawresult"))) return(res)
  stopifnot(is.data.frame(res), is(gsd, "GeneSetDb"))
  res <- copy(res)[, n := NULL]
  gs <- copy(geneSets(gsd, active.only=TRUE, as.dt=TRUE))
  gs <- gs[, list(collection, name, N, n, idx = seq_along(name))]
  gs[, Pathway := encode_gskey(gs)]
  out <- merge(gs, res, by = "Pathway")
  stopifnot(isTRUE(all.equal(out$idx, seq_len(nrow(out)))))
  out[, Pathway := NULL][, idx := NULL]
  out[, padj := p.adjust(pval, 'BH')]
}

#' Performs an overrepresentation analysis, (optionally) accounting for bias.
#'
#' This function wraps [limma::kegga()] to perform biased overrepresntation
#' analysis over gene set collection stored in a GeneSetDb (`gsd`) object. Its
#' easiest to use this function when the biases and selection criteria are
#' stored as columns of the input data.frame `dat`.
#'
#' In principle, this test does what `goseq` does, however I found that
#' sometimes calling goseq would throw errors within `goseq::nullp()` when
#' calling `makesplines`. I stumbled onto this implementation when googling
#' for these errors and landing here:
#' https://support.bioconductor.org/p/65789/#65914
#'
#' The meat and potatoes of this function's code was extracted from
#' [limma::kegga()], written by Gordon Smyth and Yifang Hu.
#'
#' Note that the BiasedUrn CRAN package needs to be installed to support biased
#' enrichment testing
#'
#' @export
#' @importFrom limma kegga
#'
#' @references
#' Young, M. D., Wakefield, M. J., Smyth, G. K., Oshlack, A. (2010).
#' Gene ontology analysis for RNA-seq: accounting for selection bias.
#' *Genome Biology* 11, R14. http://genomebiology.com/2010/11/2/R14
#'
#' @param x A data.frame with feature-level statistics. Minimally, this should
#'   have a `"feature_id"` (character) column, but read on ...
#' @param gsd The GeneSetDb
#' @param selected Either the name of a logical column in `dat` used to subset
#'   out the features to run the enrichement over, or a character vector of
#'   `"feature_id"`s that are selected from `dat[["feature_id"]]`.
#' @param groups Encodes groups of features that we can use to test selected
#'   features individual, as well as "all" together. This can be specified by:
#'   (1) specifying a name of a column in `dat` to split the enriched features
#'   into subgroups. (2) A named list of features to intersect with `selected`.
#'   By default this is `NULL`, so we only run enrichment over
#'   all elements in `selected`. See examples for details.
#' @param feature.bias If `NULL` (default), no bias is used in enrichment
#'   analysis. Otherwise, can be the name of a column in `dat` to extract
#'   a numeric bias vector (gene length, GC content, average expression, etc.)
#'   or a named (using featureIds) numeric vector of the same. The BiasedUrn
#'   CRAN package is required when this is not NULL.
#' @param universe Defaults to all elements in `dat[["feature_id"]]`.
#' @param restrict.universe See same parameter in [limma::kegga()]
#' @param plot.bias See `plot` parameter in [limma::kegga()]. You can generate
#'   this plot without running `ora` using the [plot_ora_bias()],
#'   like so:
#'   `plot_ora_bias(dat, selected = selected, groups = groups,
#'                         feature.bias = feature.bias)`
#' @param ... parameters passed to `conform()`
#' @template asdt-param
#' @return A data.frame of pathway enrichment. The last N colums are enrichment
#'   statistics per pathway, grouped by the `groups` parameter. `P.all` are the
#'   stats for all selected features, and the remaingin `P.*` columns are for
#'   the features specifed by `groups`.
#'
#' @examples
#' dgestats <- exampleDgeResult()
#' gdb <- randomGeneSetDb(dgestats)
#'
#' # Run enrichmnent without accounting for any bias
#' nobias <- ora(dgestats, gdb, selected = "selected", groups = "direction",
#'               feature.bias = NULL)
#'
#' # Run enrichment and account for gene length
#' lbias <- ora(dgestats, gdb, selected = "selected",
#'              feature.bias = "effective_length")
#'
#' # plot length bias with DGE status
#' plot_ora_bias(dgestats, "selected", "effective_length")
#'
#' # induce length bias and see what is the what ...............................
#' biased <- dgestats[order(dgestats$pval),]
#' biased$effective_length <- sort(biased$effective_length, decreasing = TRUE)
#' plot_ora_bias(biased, "selected", "effective_length")
#' etest <- ora(biased, gdb, selected = "selected",
#'              groups = "direction",
#'              feature.bias = "effective_length")
ora <- function(x, gsd, selected = "significant",
                groups = NULL,
                feature.bias = NULL, universe = NULL,
                restrict.universe = FALSE,
                plot.bias = FALSE, ...,
                as.dt = FALSE) {
  dat <- validate.xmeta(x) # enforse feature_id column
  if (is.null(universe)) universe <- dat[["feature_id"]]

  # If this is .pipelined, do we have to conform? I should check that.
  gsd <- conform(gsd, universe, ...)

  if (test_string(selected) && test_logical(dat[[selected]])) {
    selected. <- dat[["feature_id"]][dat[[selected]]]
  } else if (test_character(selected, min.len = 1L)) {
    selected. <- intersect(selected, universe)
    if (!setequal(selected., selected)) {
      warning("Only ", length(selected.), " / ", length(selected),
              "features found in 'dat'")
    }
  }

  if (!is.character(selected.)) {
    stop("Illegal argument type of `selected`: ", class(selected)[1L])
  }

  de <- list(all = selected.)

  if (!is.null(groups)) {
    if (test_string(groups) && test_character(dat[[groups]])) {
      groups <- split(dat[["feature_id"]], dat[[groups]])
    }
  }

  if (is.list(groups)) {
    if (is.null(names(groups))) {
      names(groups) <- paste0("group_", seq_along(groups))
    }
    for (group in names(groups)) {
      features <- intersect(selected., groups[[group]])
      if (length(features)) {
        if (group == "all") group <- "all2"
        de[[group]] <- features
      }
    }
  }

  if (!is.null(feature.bias)) {
    if (test_string(feature.bias) && test_numeric(dat[[feature.bias]])) {
      feature.bias <- setNames(dat[[feature.bias]], dat[["feature_id"]])
    }
    if (!is.numeric(feature.bias) && all(universe %in% names(feature.bias))) {
      warning("feature.bias vector does not cover universe: running unbiased ",
              "enrichment")
      feature.bias <- NULL
    }
  }

  if (is.numeric(feature.bias)) {
    feature.bias <- feature.bias[universe]
    if (!requireNamespace("BiasedUrn", quietly = TRUE)) {
      warning("BiasedUrn package not installed, running in unbiased mode ...",
              immediate. = TRUE)
      feature.bias <- NULL
    }
  }

  # Transform GeneSetDb into required kegga bits ...............................

  # gene.pathway is a 2d data.frame like so:
  #    GeneID      PathwayID
  #     10327  path:hsa00010
  #       124  path:hsa00010
  #       125  path:hsa00010
  #       126  path:hsa00010
  gene.pathway <- local({
    gp <- as.data.frame(gsd, active.only = TRUE)
    data.frame(GeneID = gp[["feature_id"]], PathwayID = encode_gskey(gp),
               stringsAsFactors = FALSE)
  })

  # pathway.names is a 2col data.frame, like so:
  #        PathwayID                                  Description
  #    path:hsa00010             Glycolysis / Gluconeogenesis ...
  #    path:hsa00020                Citrate cycle (TCA cycle) ...
  #    path:hsa00030                Pentose phosphate pathway ...
  pathway.names <- local({
    gs <- geneSets(gsd, active.only = TRUE)
    gs$key <- encode_gskey(gs)
    data.frame(PathwayID = gs$key, Description = gs$key,
               stringsAsFactors = FALSE)
  })

  kres <- NULL
  if (length(de[["all"]])) {
    kres <- limma::kegga(de, universe = universe, covariate = feature.bias,
                         restrict.universe = restrict.universe,
                         gene.pathway = gene.pathway,
                         pathway.names = pathway.names,
                         plot = plot.bias && !is.null(feature.bias))
  }

  res.groups <- colnames(kres)[grep("P\\..*$", colnames(kres))]
  res.groups <- sub("P\\.", "", res.groups)
  ngroups <- length(res.groups)

  kres <- if (as.dt) setDT(kres) else setDF(kres)

  setattr(kres, "mgunlist", ngroups > 1L)
  setattr(kres, "groups", res.groups)
  setattr(kres, "rawresult", TRUE)

  kres
}

#' @export
#' @importFrom stats approx
#' @importFrom limma barcodeplot
#' @describeIn ora plots the bias of coviarate to DE / selected status. Code
#'   taken from [limma::kegga()]
plot_ora_bias <- function(x, selected, feature.bias, ...) {
  assert_multi_class(x, c("data.frame", "tibble"))
  if (test_string(selected)) {
    selected <- x[[selected]]
  }
  assert_logical(selected)
  if (test_string(feature.bias)) {
    feature.bias <- x[[feature.bias]]
  }
  assert_numeric(feature.bias, len = length(selected))

  span <- approx(x = c(20,200), y = c(1, 0.5),
                 xout = sum(selected),
                 rule = 2, ties = list("ordered", mean))$y
  limma::barcodeplot(feature.bias,
                     index = selected,
                     worm = TRUE, span.worm = span,
                     main = "DE status vs covariate (manual)")
}
