test_that("renameRows works from an embedded metadata gene frame ($genes)", {
  vm <- exampleExpressionSet()
  vm$genes$symbol[3] <- NA
  vms <- renameRows(vm, "symbol")

  # Guarnatee same order of remapped object
  expect_equal(vms$E[,1], vm$E[,1], check.attributes = FALSE)

  is.symbol <- seq(nrow(vms)) != 3 & !duplicated(vm$genes$symbol)
  expect_equal(rownames(vms), ifelse(is.symbol, vm$genes$symbol, rownames(vm)))
})

test_that("renameRows works from custom data.frame", {
  vm <- exampleExpressionSet()

  # A small remap data.frame
  remap <- subset(vm$genes, symbol %in% sample(symbol, 5))
  remap <- remap[, c("entrez_id", "symbol")]
  vms <- renameRows(vm, remap)

  # Guarnatee same order of remapped object
  expect_equal(vms$E[,1], vm$E[,1], check.attributes = FALSE)

  # check that rows from remap were remapped OK
  remapped <- vms$genes$symbol %in% remap$symbol
  expect_equal(rownames(vms), ifelse(remapped, vm$genes$symbol, rownames(vm)))

  # Big remap data.frame
  vm.nona <- vm[!is.na(vm$genes$symbol),]
  vmsmall <- vm.nona[sample(nrow(vm.nona), 5),]
  remap2 <- vm.nona$genes[, c("entrez_id", "symbol")]
  vmss <- renameRows(vmsmall, remap2)

  # Guarantee same order
  expect_equal(vmsmall$E[,1], vmss$E[,1], check.attributes = FALSE)
  expect_equal(rownames(vmss), vmsmall$genes$symbol)
})

test_that("rename returns unique rownames when there are duplciates in map", {
  m <- matrix(rnorm(50), nrow = 10)
  rownames(m) <- head(letters, nrow(m))

  re <- data.frame(
    from = rownames(m),
    to = sample(tail(letters, 4), nrow(m), replace = TRUE),
    stringsAsFactors = FALSE)
  # if duplicate.policy is deault (original), let's put the original name
  # back in to see if renaming happens correctly
  re$to.o <- re$to
  re$to.o <- ifelse(duplicated(re$to.o), re$from, re$to)

  m.re <- renameRows(m, re[, 1:2])
  expect_equal(rownames(m.re), re$to.o)

  m.re.u <- renameRows(m, re[, 1:2],
                        duplicate.policy = "make.unique")
  expect_equal(sub("\\..*$", "", rownames(m.re.u)), re$to)
})

if (FALSE) {
# New complexheatmap row_labels move with matrix
library(ComplexHeatmap)
library(viridis)

m <- matrix(rnorm(50), nrow = 10)
rownames(m) <- head(letters, nrow(m))

rowdf <- data.frame(score = 1:10)
rownames(rowdf) <- rownames(m)
ranno <- rowAnnotation(
  df = rowdf)

hm1 <- Heatmap(m, show_row_names = TRUE, row_names_side = "left")

draw(hm1 + ranno)

hm2 <- Heatmap(m, show_row_names = TRUE, row_names_side = "left",
               row_labels = tail(letters, nrow(m)))
draw(hm2 + ranno)
}
