context("Scoring Genesets")
library(GSVA)

test_that('do.scoreSingleSamples.gsva is equivalent to GSVA::gsva', {
  vm <- exampleExpressionSet()
  gdb <- getMSigDBset('h')
  lol <- as.list(gdb)

  E <- vm$E
  gdb <- conform(gdb, E)

  gsva.ex <- gsva(E, lol, method='gsva', verbose=FALSE)$es.obs
  gsva.mg <- scoreSingleSamples(gdb, E, methods='gsva', verbose=FALSE)
  expect_equal(gsva.mg, gsva.ex,info='GSVA,gsva')

  # gsva.mg.melt <- scoreSingleSamples(gdb, E, methods='gsva',
  #                               verbose=FALSE, melted=TRUE)
  plage.ex <- gsva(E, lol, method='plage', verbose=FALSE)
  plage.mg <- scoreSingleSamples(gdb, E, methods='plage', verbose=FALSE)
  expect_equal(plage.mg, plage.ex,info='GSVA,gsva')

  es <- exampleExpressionSet(do.voom=FALSE)
  counts <- exprs(es)

  gsvar.ex <- gsva(counts, lol, method='gsva', rnaseq=TRUE,
                   verbose=FALSE)$es.obs
  gsvar.mg <- scoreSingleSamples(gdb, counts, method='gsva',
                            rnaseq=TRUE, verbose=FALSE)
  expect_equal(gsvar.mg, gsvar.ex, info='GSVA,gsva RNAseq')

  # mg.z <- scoreSingleSamples(gdb, E, methods='zscore',
  #                       zsummary='sqrt')
})

if (FALSE) {
  library(Biobase)
  library(multiGSEA)
  library(DESeq2)
  counts <- exprs(exampleExpressionSet(do.voom=FALSE))
  x <- CPM(counts, prior.count=.25, log=FALSE)
  X <- round(t(t(x) * attr(x, 'lib.size')))
  r <- rlog(X)
}