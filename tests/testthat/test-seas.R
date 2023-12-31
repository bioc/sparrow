context("seas")

test_that("seas fails on not-full-rank design matrix", {
  vm <- exampleExpressionSet()
  gsl <- exampleGeneSets()
  gsd <- GeneSetDb(gsl)
  design <- vm$design

  ## Add `extra` column to design matix which is linear combination
  ## other columns: not full rank
  design <- cbind(design, extra=design[, 1] + design[, 2])

  expect_error(suppressWarnings(seas(vm, gsd, design)))
})

test_that("seas wrapper generates same results as individual do.*", {
  vm <- exampleExpressionSet()
  gsl <- exampleGeneSets()
  gsd <- GeneSetDb(gsl)

  methods <- c('camera', 'cameraPR')
  min.logFC <- log2(1.25)
  max.padj <- 0.10
  mg <- seas(vm, gsd, methods, design = vm$design,
             nrot = 250, nsim = 500, split.updown = FALSE,
             feature.min.logFC = min.logFC, feature.max.padj = max.padj)
  lfc <- logFC(mg)
  gsc <- conform(gsd, vm)
  do <- sapply(methods, function(m) {
    fn <- getFunction(paste0('do.', m), where=getNamespace("sparrow"))
    fn(gsc, vm, vm$design, nrot=250, nsim=500, split.updown=FALSE,
       feature.min.logFC=min.logFC, feature.max.padj=max.padj)
  }, simplify=FALSE)

  # Some GSEA results use sampling and their outputs only converge under higher
  # iterations, which will slow down testing. To avoid that we just use methods
  # that are deterministic.
  no.random <- c('camera', 'cameraPR')
  for (m in no.random) {
    do.x <- do[[m]]
    mg.x <- mg@results[[m]]
    expect_equal(do.x, mg.x, info=m)
  }
})

test_that("seas works on GeneSetDb and BiocSet like a boss", {
  vm <- exampleExpressionSet()
  gdb <- exampleGeneSetDb()
  bsc <- exampleBiocSet()

  methods <- c("cameraPR", "fgsea")
  methods <- "cameraPR"
  # not using fgsea because I think something is goig wonky with the random
  # seed preservation since it uses BiocParallel ...
  set.seed(123)
  res.gdb <- # expect_warning({
    seas(vm, gdb, methods, design = vm$design, score.by = "t")
  # }, "ties")
  #
  set.seed(123)
  res.bsc <- # expect_warning({
    seas(vm, bsc, methods, design = vm$design, score.by = "t")
  # }, "ties")

  for (m in methods) {
    stats.gdb <- result(res.gdb, m)
    stats.bsc <- result(res.bsc, m)
    xref <- match(stats.gdb$name, stats.bsc$name)
    stats.bsc <- stats.bsc[xref,]
    expect_equal(stats.gdb$name, stats.bsc$name)
    expect_equal(
      dplyr::select(stats.bsc, -collection, -starts_with("padj")),
      dplyr::select(stats.gdb, -collection, -starts_with("padj")),
      check.attributes = FALSE)
  }
})
