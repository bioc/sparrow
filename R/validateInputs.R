#' Validate the input objects to a GSEA call.
#'
#' Checks to ensure that the values for `x`, `design`, and `contrast` are
#' appropriate for the GSEA `methods` being used. If they are kosher, then
#' "normalized" versions of these objects are returned in an (aptly) named list,
#' otheerwise an error is thrown.
#'
#' This function is strange in that we both want to verify the objects, and
#' return them in some canonical form, so it is normal for the caller to then
#' use the values for `x`, `design`, and `contrast` that are returned from this
#' call, and not the original values for these objects themselves
#'
#' I know that the validation/checking logic is a bit painful (and repetitive)
#' here. I will (perhaps) clean that up some day.
#'
#' @importFrom Matrix rankMatrix
#' @export
#'
#' @param x The expression object to use
#' @param design A design matrix, if the GSEA method(s) require it
#' @param contrast A contrast vector (if the GSEA method(s) require it)
#' @param methods A character vector of the GSEA methods that these inputs will
#'  be used for.
#' @param xmeta. hack for supportin data.frame inputs.
#' @param require.x.rownames Leave this alone, should always be `TRUE` but
#'   have it in this package for dev/testing purposes.
#' @param ... other variables that called methods can check if they want
#' @return A list with "normalized" versions of `$x`, `$design`, and `$contrast`
#'   for downstream use.
#' @examples
#' dge.stats <- exampleDgeResult()
#' ranks <- setNames(dge.stats$t, dge.stats$feature_id)
#' gdb <- exampleGeneSetDb()
#' ok <- validateInputs(ranks, gdb, methods = c("cameraPR", "fgsea"))
#' # need full expressionset & design for romer
#' null <- failWith(NULL, validateInputs(ranks, gdb, methods = "romer"))
validateInputs <- function(x, design = NULL, contrast = NULL, methods = NULL,
                           xmeta. = NULL, require.x.rownames=TRUE, ...) {
  if (is.character(methods)) {
    check.gsea.methods(methods)
  } else if (!is.null(methods)) {
    stop("Illegal type for `methods`: ", class(methods)[1L])
  }

  if (is(x, 'DGEList') && !disp.estimated(x)) {
    stop("It does not look like estimateDisp has been run on DGEList")
  }

  if ((is(x, "DGEList") || is(x, "EList"))) {
    if (is.null(x$genes)) {
      x$genes <- data.frame(feature_id = rownames(x), stringsAsFactors = FALSE)
      rownames(x$genes) <- rownames(x)
    } else if (!is.data.frame(x$genes)) {
      stop("Somehow your `$genes` object is not a data.frame, please fix your ",
           class(x)[1], " object")
    }
    if (is.null(design)) {
      design <- x$design
    }
  }

  if (is.vector(x)) {
    x <- matrix(x, ncol=1L, dimnames=list(names(x), NULL))
  }

  # Ensure there is only feature_id-like column, and this is its name.
  xmeta. <- validate.xmeta(xmeta.)

  ## Check that x is generally OK
  x.kosher <- validate.X(x, xmeta.)
  if (!isTRUE(x.kosher)) {
    stop("Bad expression object x provided: ", paste(x.kosher, collapse=','))
  }

  ## Validate the input expression object separately (not sure why now)
  if (!is.null(methods)) {
    is.valid.x <- sapply(methods, function(meth) {
      fn <- getFunction(paste0('validate.x.', meth))
      fn(x, xmeta.)
    }, simplify=FALSE)
    bad <- which(sapply(is.valid.x, Negate(isTRUE)))
    if (length(bad)) {
      msg <- paste("Error validating x for methods:",
                   paste(methods[bad], collapse=', '))
      stop(msg)
    }
  } else {
    if (!inherits(x, .valid.x)) {
      stop("Invalid expression object (x) type: ", class(x)[1L])
    }
    if (!is.character(rownames(x)) && require.x.rownames) {
      stop("The expression object does not have rownames ...")
    }
  }

  if (is.matrix(design)) {
    design.errs <- .validateDesign(x, design, xmeta.)
    if (length(design.errs)) {
      stop("Design matrix problems:\n    * ",
           paste(names(design.errs), collapse='\n    * '))
    }
    if (is.null(contrast)) {
      contrast <- ncol(design)
    } else {
      contrast <- .validateContrastVector(contrast, design)
      if (is.list(contrast)) {
        stop("Contrast vector problems:\n    * ",
             paste(names(contrast), collapse='\n    * '))
      }
    }
  }

  ## method specific validation checks
  if (is.character(methods)) {
    errs.all <- sapply(methods, function(method) {
      fn <- getFunction(paste0('validate.inputs.', method))
      errs <- fn(x, design, contrast, xmeta. = xmeta., ...)
    }, simplify=FALSE)

    errs.un <- unlist(errs.all)
    if (length(errs.un)) {
      msg <- paste("Errors in inputs:\n    *",
                   paste(names(errs.un), collapse='\n    * '))
      msg <- paste(msg, '=======', unname(errs.un), sep='\n')
      stop(msg)
    }
  }

  list(x = x, design = design, contrast = contrast, xmeta. = xmeta.,
       is.full.design = is.matrix(design))
}

#' Ensures xmeta. has one and only one feature_id-like column that is named
#' as such.
#' @noRd
validate.xmeta <- function(xmeta. = NULL, ...) {
  if (is.null(xmeta.)) return(NULL)
  xdim <- dim(xmeta.)
  is.2d <- is.integer(xdim) && length(xdim) == 2
  if (!is.2d) {
    stop("xmeta. needs to be something that is data.frame-like")
  }
  xmeta. <- as.data.frame(xmeta.)
  # if (!is.data.frame(xmeta.)) {
  #   stop("If not NULL, xmeta. must be a data.frame")
  # }
  # xref.col <- match(c("featureId", "feature_id"), colnames(xmeta.))
  # xref.col <- match("feature_id", colnames(xmeta.))
  # if (all(is.na(xref.col))) {
  #   stop("xmeta. needs a feature_id or feature_id column")
  # }
  # if (!any(is.na(xref.col))) {
  #   same.same <- isTRUE(
  #     all.equal(xmeta.[["feature_id"]], xmeta.[["feature_id"]]))
  #   if (!same.same) {
  #     stop("xmeta.$feature_id and xmeta.$feature_id do not match")
  #   }
  #   xmeta.[[xref.col[2]]] <- NULL
  #   xref.col <- xref.col[1]
  # } else {
  #   xref.col <- xref.col[!is.na(xref.col)]
  # }
  # colnames(xmeta.)[xref.col] <- "feature_id"
  stopifnot(is.character(xmeta.[["feature_id"]]))
  xmeta.
}

#' Checkes that there are no NAs in x
#' @noRd
na.check <- function(x) {
  x <- as_matrix(x, calc.norm.factors = FALSE)
  if (any(is.na(x))) stop("No NA's allowed in x")
}

#' Checks a DGEList to see if estimateDisp() was run on it
#'
#' @noRd
#' @param x Input DGEList
#' @return TRUE if yes, FALSE if no or if x is not a DGEList.
disp.estimated <- function(x) {
  # check that estimateDisp has been run
  if (!is(x, "DGEList")) return(FALSE)

  number <- c("common.dispersion")
  for (num in number) {
    kosher <- test_number(x[[num]], finite = TRUE)
    if (!kosher) {
      msg <- sprintf("[[%s]] was not found, did you `estimateDisp()`?", num)
      warning(msg, immediate. = TRUE)
      return(FALSE)
    }
  }

  numerics <- c("trended.dispersion", "tagwise.dispersion")
  for (num in numerics) {
    kosher <- test_numeric(x[[num]], finite = TRUE, any.missing = FALSE,
                           len = nrow(x))
    if (!kosher) {
      msg <- sprintf("[[%s]] was not found, did you `estimateDisp()`?", num)
      warning(msg, immediate. = TRUE)
      return(FALSE)
    }
  }

  TRUE
}

#' Returns a 0-length list when there is no error
#'
#' @noRd
.validateDesign <- function(x, design, xmeta. = NULL, ...) {
  errs <- list()
  if (!is.matrix(design)) {
    errs$design.not.matrix <- TRUE
  } else {
    if (nrow(design) != ncol(x)) {
      errs$design.discordant.dims <- TRUE
    }
    if (!is.character(colnames(design))) {
      errs$design.no.colnames <- TRUE
    }
    if (rankMatrix(design) != ncol(design)) {
      errs$design.not.full.rank <- TRUE
    }
  }
  errs
}

#' When there is no error, returns a valid contrast vector, otherwise will
#' return a named list of errors.
#'
#' I know this is a bad design!
#'
#' @noRd
.validateContrastVector <- function(contrast, design, ret.err.only=FALSE) {
  errs <- list()
  if (!is.vector(contrast) || !(is.character(contrast)||is.numeric(contrast))) {
    errs$illegal.contrast.type <- TRUE
    return(errs)
  }

  if (length(contrast) == 1L) {
    if (is.character(contrast)) {
      contrast <- which(colnames(design) == contrast)
      if (length(contrast) != 1L) {
        errs$contrast.name.not.found <- TRUE
        return(errs)
      }
    } else {
      if (as.integer(contrast) != contrast) {
        errs$numeric.contrast.not.integer <- TRUE
        return(errs)
      }
      if (contrast < 1 || contrast > ncol(design)) {
        errs$illegal.contrast.bound <- TRUE
        return(errs)
      }
    }
  } else {
    if (!is.numeric(contrast)) {
      errs$long.contrast.vector.not.numeric <- TRUE
      return(errs)
    }

    if (length(contrast) < 1 || length(contrast) > ncol(design)) {
      errs$illegal.contrast.length <- TRUE
      return(errs)
    }

    # if (abs(sum(contrast)) > 1e-5) {
    #   warning("Sum of contrast vector != 0", immediate.=TRUE)
    #   # errs$sum.contrast.not0 <- TRUE
    #   # return(errs)
    # }
  }

  if (ret.err.only || length(errs)) errs else contrast
}

#' Wrapper to check that we have valid expression, design, and contrast inputs
#' @noRd
.validate.inputs.full.design <- function(x, design, contrast,
                                         require.x.rownames=FALSE, ...) {
  errs <- list()
  if (!inherits(x, .valid.x)) {
    errs <- c(errs,
              sprintf("Invalid expression object (x) type: %s", class(x)[1L]))
  } else {
    if (!is.character(rownames(x)) && require.x.rownames) {
      errs <- c(errs, "The expression object does not have rownames ...")
    }
  }
  if (ncol(x) == 1L) {
    errs <- c(errs, 'expression matrix needs more than one column')
  }
  if (!is.matrix(design)) {
    errs$design.matrix.required <- TRUE
  } else {
    errs <- c(errs, .validateDesign(x, design))
  }
  if (!is.vector(contrast)) {
    errs$contrast.vector.required <- TRUE
  } else {
    errs <- c(errs, .validateContrastVector(contrast, design, TRUE))
  }
  errs
}

#' Check inputs when we are running seas with `method = "logFC"`
#' @noRd
.validate.inputs.logFC.only <- function(x, design, contrast, xmeta. = NULL,
                                        ...) {
  errs <- list()
  if (ncol(x) > 1) {
    errs <- .validate.inputs.full.design(x, design, contrast, ...)
  } else {
    if (is(x, 'DGEList')) {
      errs$DGEList.not.supported.for.gsd <- TRUE
    }
  }
  errs
}

#' Wrapper to check that we have a valid pre-ranked vector.
#'
#' Some GSEA functions can work on a simple (named) pre-ranked vector of
#' logFC's or t-statistcs, like limma::geneSetTest or fgsea, for example.
#' The user shoudl be able to simply provide such a pre-ranked vector, or can
#' provide a "full.design" set of inputs from which logFC's or t-statistics
#' could be computed using sparrow's internal calculateIndividualLogFC
#' function.
#'
#' @noRd
.validate.inputs.preranked <- function(x, design, contrast, ...) {
  if (is.vector(x) || is.matrix(x) && ncol(x) == 1L) {
    .validate.inputs.logFC.only(x, design, contrast, ...)
  } else {
    .validate.inputs.full.design(x, design, contrast, ...)
  }
}

## Validation Methods for Expression Objects -----------------------------------

#' Validates x has matrix-like properties
#'
#' @noRd
validate.X <- function(x, xmeta. = NULL, ...) {
  if (!inherits(x, .valid.x)) {
    return("Invalid expression object (x) type: ", class(x)[1L])
  }
  na.check(x)
  if (!is.character(rownames(x))) {
    return("The expression object does not have rownames ...")
  }
  if (any(is.na(rownames(x)))) {
    return("NAs in rownames of x")
  }
  if (any(duplicated(rownames(x)))) {
    return("Duplicated rownames in x")
  }
  if (is(x, 'DGEList')) {
    return(validate.DGEList(x))
  }
  if (!is.null(xmeta.)) {
    fid.column <- intersect(c("feature_id", "feature_id"), colnames(xmeta.))
    if (length(fid.column) != 1L) {
      return(paste("xmeta. must have one and only one of ",
                   "'feature_id', or 'feature_id' columns"))
    }
    if (!is.character(xmeta.[[fid.column]])) {
      return(paste("xmeta. '", fid.column, "' column must be character"))
    }
    if (!all(rownames(x) %in% xmeta.[[fid.column]])) {
      return("xmeta. missing entries for some rownames(x)")
    }
  }

  TRUE
}

#' @noRd
validate.DGEList <- function(x) {
  if (!isTRUE(is(x, 'DGEList'))) {
    return("x is not a DGEList")
  }
  if (!is.numeric(x$common.dispersion)) {
    return("dispersion is not estimated, minimally call estimateDisp on x")
  }
  TRUE
}

#' @noRd
validate.XwithWeights <- function(x) {
  if (!isTRUE(is(x, 'EList') || is(x, 'eSet'))) {
    return("x must be an EList or ExpressionSet")
  }
  if (is(x, 'EList')) {
    W <- x$weights
    if (!(is.matrix(W) && nrow(x) == nrow(W) && ncol(x) == ncol(W))) {
      return("EList does not have weights")
    }
  }
  if (is(x, 'eSet')) {
    if (!'weights' %in% Biobase::assayDataElementNames(x)) {
      return("weights assay not in eSet x")
    }
  }

  TRUE
}
