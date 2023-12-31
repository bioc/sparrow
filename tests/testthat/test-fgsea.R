context("fgsea")

test_that("seas calculate t and preranked t match fgsea results", {
  vm <- exampleExpressionSet()
  gdb <- exampleGeneSetDb()
  gdb <- conform(gdb, vm)

  gseaParam <- 1
  nperm <- 1000


  # Somewhere around Bioc 3.14, the RNG used with BiocParallel::SerialParam
  # is divorced from whatever happens with set.seed(), so if we want the ooutput
  # of direct alls to the fgsea functions (ie, outside of `seas`), we have to
  # wrap those calls in bplapply() so everyone uses the same random seeds.
  bpparam <- BiocParallel::SerialParam(RNGseed = 123)
  
  # Run fgsea through seas -----------------------------------------------------
  expect_warning({
    mgt <- seas(vm, gdb, 'fgsea', design = vm$design, contrast = 'tumor',
                score.by = 't', nPermSimple = nperm, gseaParam = gseaParam,
                BPPARAM = bpparam)
  }, "better estimation")
  mgres <- mgt %>%
    result("fgsea") %>%
    transform(pathway = encode_gskey(collection, name))

  # Run fgsea through do.fgsea -------------------------------------------------
  expect_warning({
    res.do <- BiocParallel::bplapply(1, function(i) {
      do.fgsea(gdb, vm, vm$design, "tumor",
               score.by = "t", nPermSimple = nperm,
               gseaParam = gseaParam,
               logFC = logFC(mgt, as.dt = TRUE))
    }, BPPARAM = bpparam)[[1]]
  }, "better estimation")

  # Run fgsea directly ---------------------------------------------------------
  gs.idxs <- as.list(gdb, active.only=TRUE, value='x.id')
  min.max <- range(sapply(gs.idxs, length))

  lfc <- logFC(mgt)
  ranks.lfc <- setNames(lfc[['logFC']], lfc[['feature_id']])
  ranks.t <- setNames(lfc[['t']], lfc[['feature_id']])

  expect_warning({
    rest <- BiocParallel::bplapply(1, function(i) {
      fgsea::fgsea(
        gs.idxs, ranks.t,
        minSize = min.max[1], maxSize = min.max[2],
        nPermSimple = nperm,
        gseaParam = gseaParam)
    }, BPPARAM = bpparam)[[1]]
  }, "better estimation")

  # compare results ------------------------------------------------------------
  # compare do.fgsea with fgsea
  expect_equal(res.do$pathway, rest$pathway)
  expect_equal(res.do$size, rest$size)
  expect_equal(res.do$ES, rest$ES)
  expect_equal(res.do$pval, rest$pval)
  expect_equal(res.do$NES, rest$NES)

  # compares seas(...) with fgsea
  expect_equal(mgres$pathway, rest$pathway)
  expect_equal(mgres$n, rest$size)
  expect_equal(mgres$ES, rest$ES)
  expect_equal(mgres$leadingEdge, rest$leadingEdge)
  expect_equal(mgres$NES, rest$NES)
  expect_equal(mgres$pval, rest$pval)

  # passing in a preranked vector gives same results ---------------------------
  expect_warning({
    set.seed(123)
    mgpre <- seas(ranks.t, gdb, "fgsea", nperm = nperm,
                  gseaParam = gseaParam, score.by = "t", BPPARAM = bpparam)
  }, "better estimation")

  rpre <- result(mgpre, 'fgsea')
  comp.cols <- c('collection', 'name', 'N', 'n', 'size', 'pval', 'ES')
  expect_equal(rpre[, comp.cols], mgres[, comp.cols])

  # Passing in data.frame works, too -------------------------------------------
  expect_warning({
    mgdf <- seas(lfc, gdb, "fgsea", nperm = nperm,
                 rank_by = "t", rank_order = "descending",
                 gseaParam = gseaParam, BPPARAM = bpparam)
  }, "better estimation")
  res.df <- result(mgdf)
  expect_equal(res.df[, comp.cols], mgres[, comp.cols])
})

