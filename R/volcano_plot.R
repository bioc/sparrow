.volcano.sources <- c(
  'SparrowResultContainer',
  'SparrowResult',
  'data.frame')

#' Create an interactive volcano plot
#'
#' Convenience function to create volcano plots from results generated within
#' this package. This is mostly used by `{sparrow.shiny}`.
#'
#' @export
#' @importFrom ggplot2 aes ggplot geom_hex
#' @importFrom plotly add_lines config ggplotly layout plotly_build
#' @inheritParams volcanoStatsTable
#' @param xlab,ylab x and y axis labels
#' @param highlight A vector of featureIds to highlight, or a GeneSetDb
#'   that we can extract the featureIds from for this purpose.
#' @param horiz_line A (optionally named) number vecor (length 1) that indicates
#'   where a line should be drawn across the volcano plot. This is usually done
#'   to signify statistical significance. When the number is "named", this
#'   indicates that you want to find an approximation of the values plotted
#'   on y based on some transformation of the values that is the named column
#'   of x (like "padj"). The default value `c(padj = 0.10)` indicates you
#'   want to draw a line at approximately where the adjust pvalue of 0.10 is
#'   on the y-axis, which is the *nominal* pvalues.
#' @param xhex The raw `.xv` (not `xtfrm(.xv)`) value that acts
#'   as a threshold such that values less than this will be hexbinned.
#' @param yhex the `.yvt` value threshold. Vaues less than this will
#'   be hexbinned.
#' @param ... pass through arguments (not used)
#' @return a ploty plot object
#' @inheritParams iplot
#' @examples
#' mg <- exampleSparrowResult()
#' volcanoPlot(mg)
#' volcanoPlot(mg, xhex=1, yhex=0.05)
volcanoPlot <- function(x, stats='dge', xaxis='logFC', yaxis='pval', idx,
                        xtfrm=base::identity,
                        ytfrm=function(vals) -log10(vals),
                        xlab=xaxis, ylab=sprintf('-log10(%s)', yaxis),
                        highlight=NULL,
                        horiz_line = c(padj = 0.10),
                        xhex=NULL, yhex=NULL,
                        width=NULL, height=NULL,
                        shiny_source='mgvolcano', ggtheme=ggplot2::theme_bw(),
                        ...) {
  # TODO: Consider updating volcanoPlot to use S3 or S4 here, or outsource
  #       this to another package, like EnhancedVolcano(?)
  dat <- volcanoStatsTable(x, stats, xaxis, yaxis, idx, xtfrm, ytfrm)

  yvals <- dat[['.yvt']]
  yrange <- range(yvals)
  ypad <- 0.05 * diff(yrange)
  ylim <- c(yrange[1] - ypad, yrange[2] + ypad)

  xvals <- dat[['.xvt']]
  xrange <- range(xvals)
  xpad <- 0.05 * diff(xrange)
  xlim <- c(xrange[1] - xpad, xrange[2] + xpad)

  ## Check if we want to hexbin some of the data: values less than
  ## abs(input$xhex) on the xaxis or less than input$yhex on the y axis
  ## should be hexbinized
  do.hex <- is.numeric(xhex) && is.numeric(yhex)
  if (do.hex) {
    reqpkg("hexbin")
    hex.me <- abs(dat[['.xv']]) <= xhex | dat[['.yvt']] <= yhex
  } else {
    hex.me <- rep(FALSE, nrow(dat))
  }

  hex <- dat[hex.me,,drop=FALSE]
  if (is.character(highlight)) {
    hlite <- dat[dat[['feature_id']] %in% highlight,,drop=FALSE]
  } else {
    hlite <- dat[FALSE,,drop=FALSE]
  }
  pts <- dat[!hex.me,,drop=FALSE]
  if (nrow(hlite)) {
    pts <- pts[!pts[['feature_id']] %in% hlite[['feature_id']],,drop=FALSE]
  }

  # silence R CMD check NOTEs
  .xvt <- .yvt <- .xv <- .yv <- NULL
  gg <- ggplot(dat, aes(.xvt, .yvt))
  if (nrow(hex)) {
    gg <- gg + geom_hex(data=hex, bins=50)
  }
  gg <- mg_add_points(gg, pts)
  gg <- mg_add_points(gg, hlite, color='red')

  ## Add horizontal line to indicate where padj of 0.10 lands
  lpos <- NULL
  if (test_number(horiz_line, null.ok = FALSE)) {
    assert_number(horiz_line, lower = 0, upper = 1)
    assert_named(horiz_line)
    assert_subset(names(horiz_line), colnames(dat))
    horiz.unit <- names(horiz_line)
    if (yaxis == horiz.unit) {
      ypos <- horiz_line
    } else {
      ## Find the pvals that are closest to qvals without going over
      # ypos <- vapply(q.thresh, function(val) {
      #   approx.target.from.transformed(val, dat[[yaxis]], dat[[horiz.unit]])
      # }, numeric(length(q.thresh)))
      ypos <- .approx_target_from_transformed(
        horiz_line,
        dat[[yaxis]],
        dat[[horiz.unit]])
      if (is.na(ypos)) {
        warning("Not drawing horiz_lines in volcano", immediate.=TRUE)
      }
    }
    names(ypos) <- NULL
    ypos <- ypos[!is.na(ypos)]
    if (length(ypos) > 0) {
      lpos <- ytfrm(ypos)
      ablabel <- if (horiz.unit == 'padj') 'q-value' else horiz.unit
      lbl <- sprintf('%s: %.2f', ablabel, horiz_line[1L])
    }
  }

  if (is(ggtheme, 'theme')) {
    gg <- gg + ggtheme
  }

  ## ggplotly messages to use github: hadley/ggplot2
  # p <- suppressMessages(ggplotly(gg, width=width, height=height, tooltip='text'))
  p <- suppressMessages({
    ggplotly(gg, width=width, height=height, source=shiny_source,
             layerData=if (nrow(hex)) 2 else 1)
  })
  if (is.numeric(lpos)) {
    p <- add_lines(p, x=seq(xrange[1] - 1, xrange[2] + 1, length=100),
                   y=rep(lpos, 100),
                   inherit=FALSE,
                   text=lbl, color=I("red"),
                   line=list(dash='dash', width=2),
                   hoverinfo='text')
  }
  p <- layout(p, dragmode="select", autosize=FALSE, xaxis=list(title=xlab),
              yaxis=list(title=ylab))
  p <- plotly_build(p)
  config(p, displaylogo=FALSE)
}

#' @noRd
#' @importFrom ggplot2 aes geom_point
mg_add_points <- function(gg, dat, color='black') {
  if (is.null(dat) || nrow(dat) == 0) {
    return(gg)
  }
  symbol <- xaxis <- yaxis <- .xv <- .yv <- NULL ## "missing symbol" NOTE
  if ('symbol' %in% names(dat)) {
    gg <- gg + suppressWarnings({
      geom_point(aes(key=feature_id,
                     text=paste0('Symbol: ', symbol, '<br>',
                                 xaxis, ': ', sprintf('%.3f', .xv), '<br>',
                                 yaxis, ': ', sprintf('%.3f', .yv))),
                 color=color, data=dat)
    })
  } else {
    gg <- gg +
      geom_point(aes(key=feature_id,
                     text=paste0('feature_id: ', feature_id, '<br>',
                                 xaxis, ': ', sprintf('%.3f', .xv), '<br>',
                                 yaxis, ': ', sprintf('%.3f', .yv))),
                 color=color, data=dat)
  }
  gg
}

#' Get the approximate nominal pvalue for a target qvalue given the
#' distribution of adjusted pvalues from the nominal ones.
#'
#' This is not an exported function, so you shouldn't be using this. This is
#' used in the volcano plot code to identify the value on the y-axis of a
#' nominal pvalues that a given corrected pvalue (FDR) lands at.
#'
#' @noRd
#'
#' @param target the FDR value you are trying to find on the nominal pvalue
#'   space (y-axis). This is a value on the FDR scale
#' @param orig the distribution of nominal pvalues
#' @param xformed the adjusted pvalues from `pvals`
#' @param thresh how close padj has to be in padjs to get its nominal
#'   counterpart
#' @return numeric answer, or NA if can't find nominal pvalue within given
#'   threshold for padjs
.approx_target_from_transformed <- function(target, orig, xformed,
                                           thresh=1e-2) {
  xdiffs <- abs(xformed - target)
  idx <- which.min(xdiffs)
  idiff <- xdiffs[idx]
  if (idiff < thresh) {
    # message("Closest padj: ", dat$padj[idx])
    out <- orig[idx]
  } else {
    # message("No pval with qval close to: ", sprintf('%.3f', val))
    out <- NA_real_
  }
  out
}

#' @noRd
.volcano_source_type <- function(x) {
  is.valid <- sapply(.volcano.sources, function(src) is(x, src))
  if (sum(is.valid) != 1L) {
    stop("Illegal object type for source of volcano: ", class(x)[1L])
  }
  .volcano.sources[is.valid]
}

#' Extracts x and y axis values from objects to create input for volcano plot
#'
#' You can, in theory, create a volcano plot from a number of different parts
#' of a [SparrowResult()] object. Most often you want to create a volcano
#' plot from the differential expressino results, but you could imagine
#' building a volcan plot where each point is a geneset. In this case, you
#' would extract the pvalues from the method you like in the
#' [SparrowResult()] object using the `stats` parameter.
#'
#' Like the [volcanoPlot()] function, this is mostly used by the
#' *sparrow.shiny* package.
#'
#' @export
#'
#' @param x A \code{SparrowResult} object, or a \code{data.frame}
#' @param stats One of \code{"dge"} or \code{resultNames(x)}
#' @param xaxis,yaxis the column of the the provided (or extracted)
#'   \code{data.frame} to use for the xaxis and yaxis of the volcano
#' @param idx The column of the \code{data.frame} to use as the identifier
#'   for the element in the row. You probably don't want to mess with this
#' @param xtfrm A function that transforms the \code{xaxis} column to an
#'   appropriate scale for the x-axis. This is the \code{identity} function
#'   by default, because most often the logFC is plotted as is.
#' @param ytfrm A function that transforms the \code{yaxis} column to an
#'   appropriate scale for the y-axis. This is the \code{-log10(yval)} function
#'   by default, because this is how we most often plot the y-axis.
#' @return a \code{data.frame} with \code{.xv}, \code{.xy}, \code{.xvt} and
#'   \code{.xvy} columns that represent the xvalues, yvalues, transformed
#'   xvalues, and transformed yvalues, respectively
#' @examples
#' mg <- exampleSparrowResult()
#' v.dge <- volcanoStatsTable(mg)
#' v.camera <- volcanoStatsTable(mg, 'camera')
volcanoStatsTable <- function(x, stats='dge', xaxis='logFC', yaxis='pval',
                             idx='idx',
                             xtfrm=identity,
                             ytfrm=function(vals) -log10(vals)) {
  stopifnot(is.function(xtfrm), is.function(ytfrm))
  type <- .volcano_source_type(x)
  if (is(x, 'SparrowResultContainer')) {
    x <- x$sr
  }
  if (is(x, 'SparrowResult')) {
    stats <- match.arg(stats, c('dge', resultNames(x)))
    if (stats == 'dge') {
      x <- logFC(x, as.dt=TRUE)
      idx <- 'feature_id'
    } else {
      x <- result(x, stats, as.dt=TRUE)
      if (missing(xaxis)) xaxis <- "mean.logFC.trim"
      idx <- 'idx'
      x[[idx]] <- encode_gskey(x)
    }
  }

  if (!is.data.frame(x)) {
    stop('x should have been converted into a data.frame by now')
  }
  x <- setDF(data.table::copy(x))
  missed.cols <- setdiff(c(xaxis, yaxis, idx), names(x))
  if (length(missed.cols)) {
    stop("Missing columns from stats data.frame from volcano object:\n  ",
         paste(missed.cols, collapse=','))
  }
  if (!'feature_id' %in% names(x)) {
    ids <- rownames(x)
    if (is.null(ids)) {
      ids <- as.character(seq_len(nrow(x)))
    }
    x[['feature_id']] <- ids
  }
  x[['.xv']] <- x[[xaxis]]
  x[['.yv']] <- x[[yaxis]]
  x[['.xvt']] <- xtfrm(x[[xaxis]])
  x[['.yvt']] <- ytfrm(x[[yaxis]])
  x
}
