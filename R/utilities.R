# The functions here are meant to be internal utility functions to this package
# and not for external/end-user use.

#' Convenience wrapper to require specified packages
#'
#' @noRd
#' @param pkg A character vector of packages to require
#' @param quietly defaults to true
#' @param ... passed into [requireNamespace()]
reqpkg <- function(pkg, quietly = TRUE, ...) {
  assert_character(pkg)
  for (p in pkg) {
    if (!requireNamespace(p, ..., quietly = quietly)) {
      stop("'", p, "' package required, please install it.", call. = FALSE)
    }
  }
}

#' Helper utility to rename specified names of a vector
#'
#' Looks for values in `x` that are specified in `names(rename)`, and changes
#' the names in `x` with the ones specified in the values of `rename`.
#'
#' @noRd
#' @param x A character  list/vector (of any type)
#' @param rename A named character vector
#' @examples
#' .replace(c("x", "y", "z"), c("y" = "why", "m" = "emm")) # c("x", "why", "z")
.replace <- function(x, rename = NULL) {
  if (is.null(rename)) return(x)
  assert_character(x)
  assert_character(rename, names = "unique")

  ridx <- match(names(rename), x)
  matched <- !is.na(ridx)
  if (any(matched)) {
    # This avoids a for loop, but nested function calls are expensive ..
    x[ridx[matched]] <- rename[matched]
    x <- .replace(x, rename)
  }

  x
}

#' An empty geneSetURL function to use when we got nothing specific
#' @noRd
.geneSetURL.NA <- function(collection, name, gdb, ...) {
  NA_character_
}

#' Retrieves a function by its name, parses out namespace::function format
#'
#' `methods::getFunction` requires you to explicitly put the package namespace
#' in the `where` parameter if you want to fish a function specifically out of
#' another package. This function parses out a `"package::function"` to put
#' the package environment in the right place.
#'
#' @noRd
#' @param name the name of the function, with an optional `"package::"` prefix
#' @return a function if found, otherwise NULL
get_function <- function(name, ...) {
  if (is.function(name)) return(name)
  assert_string(name)
  if (grepl(":::", name)) {
    stop("Can't fish out function that is not exported")
  }
  if (grepl("::", name)) {
    pkg.name <- sub("::.*", "", name)
    fn.name <- sub(".*::", "", name)
    pkg <- getNamespace(pkg.name)
    out <- getFunction(fn.name, where = pkg)
  } else {
    out <- getFunction(name)
  }
  if (!is.function(out)) {
    warning("function `", name, "` not found")
  }
  out
}

#' Utility function to ensure order of genesets in cached list used in do.*
#' methods matches the active genesets extracted from the GeneSetDb used to run
#' seas()
#'
#' @noRd
.gsdlist_conforms_to_gsd <- function(gs.idxs, gsd, active.only = TRUE, ...) {
  gsets <- geneSets(gsd, active.only = active.only, as.dt = TRUE)
  name.match <- all.equal(
    sub(".*;;", "", names(gs.idxs)),
    gsets[["name"]])
  coll.match <- all.equal(
    sub(";;.*", "", names(gs.idxs)),
    gsets[["collection"]])
  isTRUE(name.match) && isTRUE(coll.match)
}

#' A utility function to extract preranked statistics from different inputs.
#' 
#' This function will calculate the logFC of a "fully defined experimental
#' design", and ensures that the `score.by` value makes sense to use as a
#' ranking statistic.
#' 
#' @noRd
#' @return a named (unsorted) numeric vector of ranking statistics
extract_preranked_stats <- function(x, design, contrast, robust.fit=FALSE,
                                    robust.eBayes=FALSE, logFC=NULL,
                                    score.by = NULL, ...) {
  assert_string(score.by)

  if (ncol(x) > 1) {
    if (is.null(logFC)) {
      logFC <- calculateIndividualLogFC(x, design, contrast, robust.fit,
                                        robust.eBayes, ..., as.dt=TRUE)
    } else {
      is.logFC.like(logFC, x, as.error=TRUE)
    }
    stats <- assert_numeric(logFC[[score.by]])
    # t will be NA if statistics were computed using edgeR from a DGEList
    if (any(is.na(stats))) {
      stop("NA values found in ranking statistics")
    }
    names(stats) <- logFC[["feature_id"]]
  } else {
    # This is already a column matrix of precomputed things (logFC, perhaps)
    # to rank
    stats <- setNames(x[, 1L], rownames(x))
  }

  if (any(is.na(stats))) {
    stop("NA values found in ranking statistics")
  }

  if (!setequal(rownames(x), names(stats))) {
    stop("Identifiers are not setequal among stats vector and x matrix")
  }

  stats[rownames(x)]
}

#' Converts collection,name combination to key for geneset
#'
#' The "key" form often comes out as rownames to matrices and such, or
#' particularly for sending genesets down into wrapped methods, like do.camera.
#'
#' @export
#' @rdname gskey
#' @param x a data.frame with collection,name columns OR a character vector
#'   of collection names
#' @param y if `x` is a data.frame: nothing, otherwise a character vector
#'   of geneset names
#' @param sep the string to use to concatenate collections and names
#' @return a character vector
#' @examples
#' gdf <- exampleGeneSetDF()
#' gskeys <- encode_gskey(gdf)
#' gscols <- split_gskey(gskeys)
encode_gskey <- function(x, y, sep=";;") {
  if (is.data.frame(x)) {
    stopifnot(
      "collection" %in% colnames(x),
      "name" %in% colnames(x))
    y <- x[['name']]
    x <- x[['collection']]
  }
  if (is.factor(x)) x <- as.character(x)
  if (is.factor(y)) y <- as.character(y)
  stopifnot(is.character(x), is.character(y))
  paste(x, y, sep=sep)
}

#' Splits collection,name combinations to collection,name data.frames
#'
#' `splt_gskey` is the inverse function of `encode_gskey()`
#'
#' @export
#' @rdname gskey
#' @param x a character vector of encoded geneset keys from [encode_gskey()]
#' @param sep the separator used in the encoding of geneset names
#' @return a data.frame with (collection,name) columns
split_gskey <- function(x, sep=";;") {
  stopifnot(all(grepl(sep, x)))
  data.frame(
    collection=sub(sprintf("%s.*$", sep), "", x),
    name=sub(sprintf(".*?%s", sep), "", x),
    stringsAsFactors=FALSE)
}

#' Helper function to extract a vector of "pre-ranked" stats for a GSEA.
#'
#' This can come from: (1) a user provided vector; (2) the logFCs or t-stats of
#' an internal call to calculalateIndividualLogFCs from a "full design"ed
#' matrix
#'
#' @noRd
generate.preranked.stats <- function(x, design, contrast, logFC=NULL,
                                     score.by=c('t', 'logFC', 'pval')) {
  if (!is.null(logFC)) {
    is.logFC.like(logFC, x, as.error=TRUE)
    score.by <- match.arg(score.by)
    out <- setNames(logFC[[score.by]], logFC[['feature_id']])
  } else {
    ## If seas was called with a preranked vector, the validateInputs function
    ## would have converted it into a column matrix with rownames, but most
    ## preranked functions want a named vector
    out <- setNames(as.vector(x), rownames(x))
  }
  out
}


#' Converts an expression container like object to a matrix for analysis
#'
#' This converts various expression-like containers into a a matrix of values
#' for use in GSEA or single-sample based scoring methods.
#'
#' There's nothing too fancy here. Keep in mind, however, that if `y`
#' is something that typically stores counts (a `DGEList`) or
#' `DESeqDataSet`, then it is transformed into a matrix of values
#' on the log scale.
#'
#' This function is intentionally not exported.
#'
#' @noRd
#' @importFrom edgeR cpm
#'
#' @param y an object to convert into an expression matrix for use in various
#'   internal gene set based methods
#' @param gdb optional `GeneSetDb`. If this is provided, the rows of `y`
#'   are first filtered to include only the rows that are enumerated as
#'   features in this `GeneSetDb`.
#' @param calc.norm.factors If `TRUE` (default) and `y` is a `DESeqDataSet`,
#'   TMM normfactors are computed for the counts so the matrix we returned
#'   are cpms scaled using TMM normalization.
#' @return a matrix of values to use downstream of internal gene set based
#'   methods.
as_matrix <- function(y, gdb = NULL, calc.norm.factors = TRUE, prior.count = 3,
                      ...) {
  if (!is.null(gdb)) stopifnot(is(gdb, "GeneSetDb"))
  if (is(y, "SummarizedExperiment")) {
    if (!requireNamespace("SummarizedExperiment")) {
      stop("SummarizedExperiment package required to work on a SE")
    }
  }
  if (is(y, "DESeqDataSet") && calc.norm.factors) {
    y <- edgeR::DGEList(SummarizedExperiment::assay(y))
    y <- edgeR::calcNormFactors(y)
  }


  if (is.vector(y)) {
    y <- t(t(y)) ## column vectorization that sets names to rownames
  } else if (is(y, 'EList')) {
    y <- y$E
  } else if (is(y, 'DGEList')) {
    y <- cpm(y, prior.count = prior.count, log=TRUE)
  } else if (is(y, 'eSet')) {
    ns <- tryCatch(loadNamespace("Biobase"), error = function(e) NULL)
    if (is.null(ns)) stop("Biobase required")
    y <- ns$exprs(y)
  } else if (is.data.frame(y)) {
    y <- as.matrix(y)
  } else if (is(y, "SingleCellExperiment")) {
    if (!"logcounts" %in% SummarizedExperiment::assayNames(y)) {
      stop("`logcounts` assay missing from SingleCellExperiment")
    }
    y <- SummarizedExperiment::assay(y, "logcounts")
  } else if (is(y, "Matrix")) {
    # y <- Matrix::as.matrix(y)
    y <- y
  }

  if (!is.null(gdb)) {
    keep <- rownames(y) %in% featureIds(gdb, active.only = FALSE)
    y <- y[keep,,drop = FALSE]
  }

  stopifnot(
    (is.matrix(y) && is.numeric(y)) || (is(y, "Matrix") && is(y, "Mnumeric"))
  )
  y
}

#' Reads in a semi-annotated genelist (one symbol per line)
#'
#' Often we are given a list of gene names, and the symbols provided are not
#' the official HGNC ones. In these cases (when small enough) I will replace
#' the symbol provided by the official one, and leave the submitted symbol
#' there after a comment character ("#"). This just strips the stuff after
#' the comment character to provide only the offiical symbols.
#'
#' @noRd
#' @param fn the path to the gene list file
#' @return character vector of gene names.
readGeneSymbols <- function(fn) {
  out <- readLines(fn)
  sub(' +#.*', '', out)
}

#' @noRd
isSingleCharacter <- function(x, allow.na=FALSE) {
  is.character(x) && length(x) == 1L && (!is.na(x) || allow.na)
}

#' @noRd
isSingleInteger <- function(x, allow.na=FALSE) {
  is.integer(x) && length(x) == 1L && (!is.na(x) || allow.na)
}

#' @noRd
isSingleNumeric <- function(x, allow.na=FALSE) {
  is.numeric(x) && length(x) == 1L && (!is.na(x) || allow.na)
}

#' @noRd
isSingleLogical <- function(x, allow.na=FALSE) {
  is.logical(x) && length(x) == 1L && (!is.na(x) || allow.na)
}

#' Check a data.table vs a reference data.table
#'
#' This function ensures that a \code{data.table} \code{x} has a superset of
#' columns of a reference table \code{ref}, and that both tables are keyed by
#' the same columns.
#'
#' @noRd
#'
#' @param x A `data.table` you want to be validated
#' @param ref `data.table` to use as the reference/model data.table
#'
#' @return `TRUE` if all things check out, otherwise a character vector
#'   indicating what the problems were.
check.dt <- function(x, ref) {
  if (!is.data.table(x)) {
    stop("Input is not a data.table")
  }
  missed.cols <- setdiff(names(ref), names(x))
  if (length(missed.cols)) {
    msg <- paste('columns missing:', paste(missed.cols, collapse=','))
    return(msg)
  }

  pk <- key(ref)
  if (!is.null(pk)) {
    xk <- key(x)
    if (length(pk) != length(xk) || !all(pk == xk)) {
      return('illegal key set')
    }
  }

  TRUE
}


## Random Utilities ------------------------------------------------------------

#' Utility function to cat a message to stderr (by default)
#'
#' @export
#' @param ... pieces of the message
#' @param file where to send the message. Defaults to \code{stderr()}
#' @return Nothing, dumps text to `file`
#' @examples
#' msg("this is a message", "to stderr")
msg <- function(..., file=stderr()) {
  cat(paste(rep('-', 80), collapse=''), '\n', file=file)
  cat(..., '\n', file=file)
  cat(paste(rep('-', 80), collapse=''), '\n', file=file)
}

#' Utility function to try and fail with grace.
#'
#' Inspired from one of Hadley's functions (in plyr or something?)
#'
#' @export
#'
#' @param default the value to return if `expr` fails
#' @param expr the expression to take a shot at
#' @param frame the frame to evaluate the expression in
#' @param message the error message to display if `expr` fails. Deafults
#'   to [base::geterrmessage()]
#' @param silent if `TRUE`, sends the error message to [msg()]
#' @param file where msg sends the message
#' @return the result of `expr` if successful, otherwise `default` value.
#' @examples
#' # look, this doesn't throw an error, it just returns NULL
#' x <- failWith(NULL, stop("no error, just NULL"), silent = TRUE)
failWith <- function(default=NULL, expr, frame=parent.frame(),
                     message=geterrmessage(), silent=FALSE, file=stderr()) {
  tryCatch(eval(expr, frame), error=function(e) {
    if (!silent) msg(message, file)
    default
  })
}
