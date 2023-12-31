set.seed(123)

# The example DGEList included in this package was created from a serialized
# TCGA dataset that is not readily available, but all the subsequent data
# objects were created from there with this script.
#
# In the future, the internal dataset will be removed and we can rely on
# some of the experimental data package available through ExperimentHub or
# as a bioconductor package itself.

## -----------------------------------------------------------------------------
## Setup the dataset for testing
per.group <- 5

library(DESeq2)
brca.fn <- file.path('~/tmp/TCGA-rnaseq-BRCA.rds')
x <- readRDS(brca.fn)

out <- x[, (x$PAM50confidence == 1 & !is.na(x$PAM50confidence)) | x$Cancer_Status == 'normal']
pcols <- c('sizeFactor', 'Sample_ID', 'Patient_ID', 'Cancer_Status',
           'PAM50subtype')
colData(out) <- colData(out)[, pcols]

normal.take <- sample(which(out$Cancer_Status == 'normal'), per.group)
subs <- head(names(table(out$PAM50subtype)), 3)
sub.take <- sapply(subs, function(s) sample(which(out$PAM50subtype == s), per.group))

take <- c(normal.take, as.vector(sub.take))

out <- out[,take]
out <- out[rowSums(counts(out)) > 1,]
rownames(out) <- sub('GeneID:', '', rownames(out))

library(edgeR)
y <- edgeR::DGEList(
  counts(out),
  genes = as.data.frame(rowData(out))[, 'symbol', drop=FALSE],
  samples = as.data.frame(colData(out)))
y <- edgeR::calcNormFactors(y)
saveRDS(y, 'TCGA-BRCA-some.DGEList.rds')

## -----------------------------------------------------------------------------
## Setup the most base of genesets
load_pkg('sparrow')
.gsets <- getMSigGeneSetDb(c('c2', 'c6', 'c7'))

## This list is of the type that GeneSetDb expects, ie: a list of lists,
## where the top level list has elements from different "gene set groups". Each
## of these is a named list of gene sets, each of which is a character vector
## that lists the entrezIDs in each geneset.
##
## Unlisting this list-of-list ubjects (recursive=FALSE) is the type of input
## the camera and roast expect for their input.


## g.some.gs: This will be used a the geneset "list-of-lists" that can
##            construct sparrow::GeneSetDb objects.
##
##            30 GeneSets in total, 10 of them are hopefully
##            "breast cancer specific"
g.gsets.lol <- lapply(.gsets, function(x) {
  breast <- grep('breast', names(x), ignore.case=TRUE)
  esr <- grep('esr', names(x), ignore.case=TRUE)
  specific <- unique(c(breast, esr))
  if (length(specific) > 10) {
    specific <- sample(specific, 10)
  }
  random <- sample(setdiff(seq(x), c(breast, esr)), 20)
  x[unique(c(specific, random))]
})

saveRDS(g.gsets.lol, 'genesets-sparrow-list-of-lists.rds')

## Create index vectors into vm.all that the "normal" limma GSEA methods
## expect as input.
g.gsets.limma <- unlist(gsets.lol, recursive = FALSE)
saveRDS(g.gsets.limma, 'genesets-limma-idxvectors.rds')

