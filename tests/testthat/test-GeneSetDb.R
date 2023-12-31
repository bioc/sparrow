context("GeneSetDb")

## TODO: These tests need to be added to test-GeneSetDb
##  * test the URL functions
##  * test various collectionMetadata manipulation, ie:
##      - collectionMetadata(x)
##      - collectionMetadata(x, collection)
##      - collectionMetadata(x, collection, name)
##  * test collectionMetadata<- ensures single collection,name pairs

test_that("GeneSetDb constructor preserves featureIDs per geneset", {
  ## This test exercise both the single list and list-of-lists input for geneset
  ## membership info.
  gsl <- exampleGeneSets()
  gsd <- GeneSetDb(gsl)
  expect_is(gsd, 'GeneSetDb')

  ## ids in gsd@db should match input lists
  ## This test is not exercising the API that fetches featureIds, but rather
  ## retrieves them using the back door -- this is intentional.
  for (xgrp in names(gsl)) {
    for (xid in names(gsl[[xgrp]])) {
      gsd.ids <- gsd@db[list(xgrp, xid)]$feature_id
      expected.ids <- gsl[[xgrp]][[xid]]
      info.lol <- sprintf('collection %s id %s', xgrp, xid)
      expect_true(setequal(expected.ids, gsd.ids), info=info.lol)
      expect_false(any(duplicated(gsd.ids)), info=info.lol)
    }
  }
})

test_that("GeneSetDb constructor works with an input data.frame", {
  gdb0 <- GeneSetDb(exampleGeneSets())
  df <- as.data.frame(gdb0)

  # Adding a fake symbol here, just to see what is the what
  meta <- data.frame(feature_id=unique(df$feature_id), stringsAsFactors=FALSE)
  faux <- replicate(nrow(meta),
                    paste(sample(letters, 5, replace=TRUE), collapse=""))
  meta$symbol <- faux
  df.in <- merge(df, meta, by='feature_id')

  # A warning is fired if merging extra columns (symbol, here) hoses something
  # in the GeneSetDb, so let's make sure there is no such warning here.
  gdb <- GeneSetDb(df.in[sample(nrow(df.in)),]) ## randomize rows for fun
  expect_equal(gdb, gdb0, features.only=TRUE)

  # Check that the symbol column from df.in was added to gdb@db
  expect_is(gdb@db$symbol, 'character')

  # Constructor works when collection and/or name are factors
  dff <- transform(df, collection = factor(collection), name = factor(name))
  gdb2 <- GeneSetDb(dff)
  expect_equal(gdb2, gdb0)
})

test_that("gene- and gene-set level metadata data perserved via GeneSetDb.data.frame constructor", {
  gdb <- exampleGeneSetDb()
  gdf <- copy(gdb@db)
  gdf[, glevel := sample(letters, nrow(gdf), replace = TRUE)]
  gdf[, gslevel := .N, by = c("collection", "name")]
  gdb2 <- GeneSetDb(gdf)

  # Test that genesetlevel annotation is legit and correct
  expect_equal(gdb@table[, list(collection, name, active, N)],
               gdb2@table[, list(collection, name, active, N)])
  expect_equal(gdb2@table$N, gdb2@table$gslevel)

  # Test that the geneleve annotations are correct
  expect_equal(gdb2@db[, list(collection, name, feature_id, glevel)],
               gdf[, list(collection, name, feature_id, glevel)])
})

test_that("addGeneSetMetadata doesn't adds geneset metadata appropriately", {
  gdb <- exampleGeneSetDb()
  meta <- transform(geneSets(gdb, as.dt = TRUE)[, c("collection", "name")],
                    var1 = sample(letters, length(name), replace = TRUE),
                    var2 = sample(1:100, length(name), replace = TRUE))
  gtbl <- copy(gdb@table)
  gdu <- addGeneSetMetadata(gdb, meta)

  expect_equal(gdu@table[, list(collection, name, active, N, n)],
               gtbl[, list(collection, name, active, N, n)])
  expect_equal(meta[, list(collection, name, var1, var2)],
               gdu@table[, list(collection, name, var1, var2)])
})

test_that("GeneSetDb contructor converts GeneSetCollection properly", {
  gdb.all <- exampleGeneSetDb()
  # geneset collections do not handle "collection" like we do, so subset
  # to just one
  gdb.c2 <- gdb.all[gdb.all@table$collection == "c2"]
  gsc <- as(gdb.c2, 'GeneSetCollection')
  gdbn <- GeneSetDb(gsc, collectionName = "c2")
  expect_equal(gdbn, gdb.c2, features.only=TRUE)
})

test_that("GeneSetDb contructor converts list of GeneSetCollection properly", {
  gdb.all <- exampleGeneSetDb()
  gdb.c2 <- gdb.all[gdb.all@table$collection == "c2"]
  gdb.c7 <- gdb.all[gdb.all@table$collection == "c7"]
  gdbo <- combine(gdb.c2, gdb.c7)

  gscl <- list(c2 = as(gdb.c2, 'GeneSetCollection'),
               c7 = as(gdb.c7, 'GeneSetCollection'))
  gdbn <- GeneSetDb(gscl)

  # Ensure that collection names are preserved, since gscl is a named list
  # of collections
  expect_equal(gdbn, gdbo)
})

test_that("GeneSetDb constructor honors custom collectionName args", {
  gdb.all <- exampleGeneSetDb()
  gdb.c2 <- gdb.all[gdb.all@table$collection == "c2"]
  gdb.c7 <- gdb.all[gdb.all@table$collection == "c7"]
  gdbo <- combine(gdb.c2, gdb.c7)

  lol <- as.list(gdbo, nested=TRUE)
  new.cnames <- setNames(c('x1', 'x2'), names(lol))

  ## Change collectionName from h,c6 to c2,c1
  gdbn <- GeneSetDb(lol, collectionName=new.cnames)
  gso <- geneSets(gdbo)
  for (oname in names(new.cnames)) {
    nname <- new.cnames[oname]
    gs.names <- subset(geneSets(gdbo), collection == oname)$name
    for (gs.name in gs.names) {
      oids <- featureIds(gdbo, oname, gs.name)
      nids <- featureIds(gdbn, nname, gs.name)
      expect_true(setequal(nids, oids),
                  info=sprintf("feature_id parity for (%s:%s, %s)",
                               oname, nname, gs.name))
    }
  }
})

test_that("as(gdb, 'GeneSetCollection') preserves featureIds per GeneSet", {
  gdb <- exampleGeneSetDb()
  gsc <- as(gdb, 'GeneSetCollection')
  for (gs in gsc) {
    gs.info <- strsplit(GSEABase::setName(gs), ';')[[1]]
    coll <- gs.info[1]
    name <- gs.info[2]
    expect_true(
      setequal(GSEABase::geneIds(gs), featureIds(gdb, coll, name)),
      info=sprintf("feature_id match for geneset (%s,%s)", coll, name))
  }
})

test_that("featureIds(GeneSetDb, i, j) accessor works", {
  gsl <- exampleGeneSets()
  gsd <- GeneSetDb(gsl)

  for (group in names(gsl)) {
    for (id in names(gsl[[group]])) {
      expected.ids <- gsl[[group]][[id]]
      gsd.ids <- featureIds(gsd, group, id)
      msg <- sprintf("unexpected ids returned featureIds(gsd, %s, %s)", group, id)
      expect_true(setequal(expected.ids, gsd.ids), info=msg)
    }
  }
})

## This test and the conform,GeneSetDb test below are testing similar things
test_that("featureIds(GeneSetDb, i, j) removes 'unconformable' featureIds", {
  vm <- exampleExpressionSet()
  gsl <- exampleGeneSets()
  gsd <- GeneSetDb(gsl)
  gsc <- conform(gsd, vm)

  ## This assumes all genesets passed in are "active"
  for (group in names(gsl)) {
    for (id in names(gsl[[group]])) {
      all.ids <- gsl[[group]][[id]]
      expected.ids <- intersect(all.ids, rownames(vm))
      gsc.ids.all <- featureIds(gsc, group, id, active.only=FALSE)
      gsc.ids <- featureIds(gsc, group, id)
      msg <- "unexpected ids returned featureIds(gsd, %s, %s), fetch.all=%s"
      expect_true(setequal(expected.ids, gsc.ids),
                  info=sprintf(group, id, FALSE))
      expect_true(setequal(all.ids, gsc.ids.all),
                  info=sprintf(group, id, TRUE))
    }
  }
})

test_that("featureIds(GeneSetDb, i, MISSING) gets all features in a collection", {
  vm <- exampleExpressionSet()
  gsl <- exampleGeneSets()
  gsd <- GeneSetDb(gsl)
  gsc <- conform(gsd, vm)

  cols <- unique(geneSets(gsd)$collection)
  for (col in cols) {
    fids <- featureIds(gsd, col)
    expected <- unique(subset(gsd@db, collection == col)$feature_id)
    expect_true(setequal(expected, fids), info=paste("collection:", col))
  }

  ## Uncformable features dropped
  for (col in cols) {
    fids <- featureIds(gsc, col)
    expected <- intersect(subset(gsd@db, collection == col)$feature_id,
                          rownames(vm))
    expect_true(setequal(expected, fids),
                info=paste("active collection:", col))
  }
})

test_that("conform,GeneSetDb follows row permutation in expression object", {
  y <- exampleExpressionSet(do.voom=FALSE)
  y.mixed <- y[sample(nrow(y)),]
  y.sub <- y[sample(nrow(y), 100),]

  gsd <- GeneSetDb(exampleGeneSets())

  gsd.es <- conform(gsd, y)
  gsd.mixed <- conform(gsd, y.mixed)

  # gsd.sub is super small, so we expect a warning due to not being able to
  # match many featureIds to the expression object
  expect_warning({
    gsd.sub <- conform(gsd, y.sub)
  }, "^fraction .* low:", ignore.case=TRUE)

  # gsd.es and gsd.mixed should have the same features in them but different
  # x.id
  expect_equal(geneSets(gsd.es), geneSets(gsd.mixed))
  gt <- geneSets(gsd.es)
  gt.sub <- geneSets(gsd.sub)

  for (i in seq_len(nrow(gt))) {
    grp <- gt$collection[i]
    xid <- gt$name[i]
    n <- gt$n[i]
    label <- sprintf("(%s, %s)", gt$collection[i], gt$name[i])
    # The feature IDs of fids.es and fids.mix must be the same
    fids.es <- featureIds(gsd.es, grp, xid)
    fids.mix <- featureIds(gsd.mixed, grp, xid)
    expect_equal(n, length(fids.es))
    expect_true(setequal(fids.es, fids.mix))

    # Ensure that the $x.idx's for each match the rownames of the expression
    # object
    es.rn <- rownames(y)[featureIds(gsd.es, grp, xid, 'x.idx')]
    es.mixed.rn <- rownames(y.mixed)[featureIds(gsd.mixed, grp, xid, 'x.idx')]
    expect_true(setequal(es.rn, es.mixed.rn), info=label)
    expect_true(setequal(es.rn, fids.es), info=label)

    ## Was this geneset deactivated in the subset gt?
    if (is.active(gsd.sub, grp, xid)) {
      fids.sub <- featureIds(gsd.sub, grp, xid)
      n.sub <- gsd.sub@table[list(grp, xid)]$n
      expect_equal(n.sub, length(fids.sub))
      expect_true(length(fids.sub) <= length(fids.es))
      ## sub features are subset of original features
      expect_true(length(setdiff(fids.sub, fids.es)) == 0)

      ## check that the rownames of the expression object match the features
      ## returned "by index"
      es.sub.rn <- rownames(y.sub)[featureIds(gsd.sub, grp, xid, 'x.idx')]
      expect_true(setequal(fids.sub, es.sub.rn),
                  info = sprintf("gsd.sub: %s,%s", grp, xid))
    }
  }
})

test_that("combine,GeneSetDb works", {
  gsl <- exampleGeneSets()
  gsd <- GeneSetDb(gsl)
  extra <- list(more=list(first=head(letters, 10), second=tail(letters, 10)))
  gst2 <- combine(gsd, GeneSetDb(extra))
  expect_is(gst2, 'GeneSetDb')
  expect_true(validObject(gst2))

  all.gsl <- c(gsl, extra)

  ## Ensure that all new and old features are in the new GeneSetDb
  for (group in names(all.gsl)) {
    for (id in names(all.gsl[[group]])) {
      info <- sprintf('combined collection: %s, name %s', group, id)
      expected <- all.gsl[[group]][[id]]
      fids <- featureIds(gst2, group, id)
      expect_true(setequal(expected, fids), info=info)
    }
  }
})

test_that("gene set metadata kept pre/post conform,GeneSetDb", {
  y <- exampleExpressionSet(do.voom = FALSE)
  gsd <- GeneSetDb(exampleGeneSets())
  gsd@table$metacol <- sample(letters, nrow(gsd@table), replace=TRUE)
  gsdc <- conform(gsd, y)

  gs.o <- geneSets(gsd)
  gs.c <- geneSets(gsdc)

  expect_equal(
    gs.o[, !names(gs.o) %in% c('active', 'n')],
    gs.c[, !names(gs.c) %in% c('active', 'n')])
})

test_that("combine,GeneSetDb honors geneset metadata in columns of geneSets()", {
  gdb.all <- exampleGeneSetDb()
  # split and add gdb-specific metadata
  gdb.c2   <- gdb.all[gdb.all@table$collection == "c2"]
  gdb.c2@table$c2only <- "stuff"

  gdb.rest <- gdb.all[gdb.all@table$collection != "c2"]
  gdb.rest@table$rest <- "things"
  gdb2 <- combine(gdb.c2, gdb.rest)

  # Check that all columns are there
  gs.c2 <- geneSets(gdb.c2, as.dt = TRUE)
  gs.rest <- geneSets(gdb.rest, as.dt = TRUE)
  gs.2 <- geneSets(gdb2, as.dt = TRUE)
  expect_setequal(c(names(gs.c2), names(gs.rest)), names(gs.2))
})

test_that("combine,GeneSetDb's that have duplicate genesets works", {
  gdb.all <- exampleGeneSetDb()
  # split and add gdb-specific metadata
  gdb.c2   <- gdb.all[gdb.all@table$collection == "c2"]
  gdb.c2@table$c2only <- "stuff"

  gdb.rest <- gdb.all[gdb.all@table$collection != "c7"]
  gdb.rest@table$rest <- "things"
  gdb2 <- combine(gdb.c2, gdb.rest)

  # Check that all columns are there
  gs.c2 <- geneSets(gdb.c2, as.dt = TRUE)
  gs.rest <- geneSets(gdb.rest, as.dt = TRUE)
  gs.2 <- geneSets(gdb2, as.dt = TRUE)
  expect_setequal(c(names(gs.c2), names(gs.rest)), names(gs.2))

  # duplicate genesets should have entries for both `c2only` and `rest`
  has.both <- gs.2$collection == "c2"
  is.complete <- complete.cases(gs.2[, .(c2only, rest)])
  expect_true(all(is.complete[has.both]))
  expect_true(!any(is.complete[!has.both]))
})

test_that("as.*.GeneSetDb conversions honor `active.only` requests", {
  set.seed(0xBEEF)
  # create a "short" expressionset so that many genes do not conform
  vm.all <- exampleExpressionSet(do.voom = FALSE)
  vm <- vm.all[sample(nrow(vm.all), 100),]
  gdb <- exampleGeneSetDb()
  gdbc <- expect_warning(conform(gdb, vm), "deactivating", ignore.case = TRUE)

  gs.all <- gdb@table$name
  gs.active <- subset(gdbc@table, active)$name
  inactive <- setdiff(gs.all, gs.active)
  expect_true(length(inactive) > 0)

  gdb.df <- as.data.frame(gdb)
  gdbc.df <- as.data.frame(gdbc)
  expect_true(nrow(gdbc.df) < nrow(gdb.df))

  expect_true(setequal(gs.all, gdb.df$name))
  expect_true(setequal(gs.active, gdbc.df$name))
})

test_that("Conformed GeneSetDb returns only matched genes on data.frame conversion", {
  vm <- exampleExpressionSet()
  gdb <- exampleGeneSetDb()
  gdbc <- conform(gdb, vm)

  # Ensure that there are some features missing in vm that are in the gdb
  expect_true(any(geneSets(gdbc)$n < geneSets(gdbc)$N))

  gdb.df <- as.data.frame(gdb)
  gdbc.df <- as.data.frame(gdbc)

  extra.genes <- setdiff(gdb.df$feature_id, rownames(vm))
  matched.genes <- intersect(gdb.df$feature_id, rownames(vm))
  expect_true(length(extra.genes) > 0)
  expect_true(length(matched.genes) > 0)

  expect_true(!all(gdb.df$feature_id %in% rownames(vm)))
  expect_true(all(gdbc.df$feature_id %in% rownames(vm)))
})

test_that("as.list.GeneSetDb returns gene sets in same order as GeneSetDb", {
  es <- exampleExpressionSet()
  gsd <- conform(exampleGeneSetDb(), es)

  gs.idxs <- as.list(gsd)
  info <- strsplit(names(gs.idxs), ';;')
  res <- data.table(collection=sapply(info,'[[',1L), name=sapply(info,'[[',2L))
  expected <- geneSets(gsd, active.only=TRUE, as.dt=TRUE)
  expect_equal(res, expected[, list(collection, name)], check.attributes=FALSE)
})

test_that("as.list.GeneSetDb returns proper indexes into conformed object", {
  es <- exampleExpressionSet()
  gsi <- exampleGeneSets(es)

  gsl <- exampleGeneSets()
  gsd <- conform(GeneSetDb(gsl), es)
  indexes <- as.list(gsd, 'x.idx', nested=TRUE)

  for (xgrp in names(gsl)) {
    for (xid in names(gsl[[xgrp]])) {
      expected <- match(gsl[[xgrp]][[xid]], rownames(es))
      expected <- expected[!is.na(expected)]
      gsd.idxs <- indexes[[xgrp]][[xid]]
      expect_true(setequal(expected, gsd.idxs),
                  info=sprintf("%s,%s", xgrp, xid))
    }
  }
})

test_that("conformed & unconformed GeneSetDb,incidenceMatrix is kosher", {
  es <- exampleExpressionSet()
  gsl <- exampleGeneSets()
  gsd <- GeneSetDb(gsl)
  gsdc <- conform(gsd, es)

  im <- incidenceMatrix(gsd)
  imc <- incidenceMatrix(gsdc)
  gs.tuple <- split_gskey(rownames(im))
  for (i in seq_len(nrow(im))) {
    col <- gs.tuple$collection[i]
    name <- gs.tuple$name[i]
    fidx <- im[i,] == 1
    fidxc <- imc[i,] == 1

    fids <- gsl[[col]][[name]]
    fidsc <- intersect(fids, rownames(es))

    im.fids <- colnames(im)[fidx]
    imc.fids <- colnames(imc)[fidxc]
    ## Check ids from incidence matrix
    expect_true(setequal(im.fids, fids), info=paste(i, "unconformed GeneSetDb"))
    expect_true(setequal(imc.fids, fidsc), info=paste(i ,"conformed GeneSetDb"))
  }
})

test_that("annotateGeneSetMembership works", {
  vm <- exampleExpressionSet()
  gdb <- GeneSetDb(exampleGeneSets())
  mg <- seas(vm, gdb, design = vm$design, contrast = ncol(vm$design))
  lfc <- logFC(mg)

  ## Test that annotation is consistent with pre-conformed gdb vs uncormed
  lfc.anno.u <- annotateGeneSetMembership(lfc, gdb)    ## unconformed
  lfc.anno.p <- annotateGeneSetMembership(lfc, mg@gsd) ## preconformed
  expect_equal(lfc.anno.u, lfc.anno.p)

  ## ensure that annotateGeneSetMembership guessed the right column
  lfc.anno.x <- annotateGeneSetMembership(lfc, gdb, x.ids=lfc$feature_id)
  expect_equal(lfc.anno.x, lfc.anno.u)

  ## ensure that x.ids specified by column name in lfc works
  lfc.anno.c <- annotateGeneSetMembership(lfc, gdb, x.ids='feature_id')
  expect_equal(lfc.anno.x, lfc.anno.c)
})

test_that("subsetByFeatures returns correct genesets for features", {
  set.seed(0xBEEEF)
  gdb <- exampleGeneSetDb()
  features <- sample(featureIds(gdb), 10)
  gdb.sub <- subsetByFeatures(gdb, features)

  db.all <- gdb@db
  db.sub <- gdb.sub@db
  db.rest <- anti_join(
    as.data.frame(db.all),
    as.data.frame(db.sub),
    by=c('collection', 'name'))
  db.rest <- as.data.table(db.rest)

  # db.sub + db.rest should == db.all
  expect_equal(nrow(db.sub) + nrow(db.rest), nrow(db.all))

  # 1. Ensure that each geneset in subsetted gdb (gdb.sub) has >= 1
  #    of requested features in its feature_id column.
  has.1 <- db.sub[, {
    list(N=.N, n=sum(feature_id %in% features))
  }, by=c('collection', 'name')]
  expect_true(all(has.1$n >= 1))

  # 2. Ensure that any geneset not in the subsetted GeneSetDb doesn't have
  #    any of the requested features
  has.0 <- db.rest[, {
    list(N=.N, n=sum(feature_id %in% features))
  }, by=c('collection', 'feature_id')]
  expect_true(all(has.0$n) == 0)
})

test_that('subset.GeneSetDb ("[".GeneSetDb) creates valid result', {
  set.seed(1234)
  gdb <- exampleGeneSetDb()
  keep <- sample(c(TRUE, FALSE), length(gdb), replace=TRUE)
  sdb <- gdb[keep]
  expect_equal(length(sdb), sum(keep))
  expect_equal(geneSets(sdb)$name, geneSets(gdb)$name[keep])

  ## check counts
  # NOTE: remove count collectionMetadata
  # sdb.coll.counts <- collectionMetadata(sdb, as.dt=TRUE)[name == 'count']
  # sdb.coll.counts[, value := unlist(value)]
  # exp.coll.counts <- geneSets(sdb, as.dt=TRUE)[, {
  #   .(name='count', value=.N)
  # }, by='collection']
  # setkeyv(exp.coll.counts, c('collection', 'name'))
  # expect_equal(sdb.coll.counts, exp.coll.counts)
  # expect_true(validObject(sdb))
})

test_that("Simple BiocSet <-> GeneSetDb conversions work", {
  gs.list <- unlist(exampleGeneSets(), recursive = FALSE)
  names(gs.list) <- sub(".*??\\.", "", names(gs.list))

  # BiocSet can be created from a list of features, we'll match our conversions
  # to this
  bs.ex <- BiocSet::BiocSet(gs.list)
  gdb <- GeneSetDb(gs.list, collectionName = "collection")

  # GeneSetDb to BiocSet conversion:
  bs.out <- as(gdb, "BiocSet")
  expect_equal(bs.out, bs.ex, check.attributes = FALSE)

  gdb.bs <- GeneSetDb(bs.ex, collectionName = "collection")
  expect_equal(gdb.bs, gdb)
})
