#' Returns the relevant featureIds for a given geneset.
#'
#' @description
#' Gene sets are defined by the unique compound key consisting of their
#' `collection` and `name`. To fetch the featureIds associated with
#' a specific geneset, you must provide values for `i` and `j`. If
#' these are missing, then a character vector of all the unique feature ids
#' within `x` are returned.
#'
#' If the GeneSetDb `x` has been conformed to an expression object this
#' will default to return only the feature_id's that are matched to the target
#' expression object, and they will be returned using the same identifiers that
#' the target expression object uses. To change this behavior, tweak the values
#' for the `active.only` and `value` parameters, respectively.
#'
#' `x` can be either a `GeneSetDb` or a `SparrowResult`. If its the latter,
#' then this call simply delegates to the internal `GeneSetDb`.
#'
#' @rdname featureIds
#' @exportMethod featureIds
#'
#' @param x Object to retrieve the gene set from, either a `GeneSetDb` or a
#'   `SparrowResult`.
#' @param i,j The collection,name compound key identifier of the gene set
#' @param value What form do you want the id's in?
#'   * `"feature_id"`: the IDs used in the original geneset definitions
#'   * `"x.id"`: the ids of the features as they are used in the expression
#'     object.
#'   * `"x.idx"`: The integer index into the expresion object `x` that the
#'     `GeneSetDb`` has been conformed to.
#' @param active.only only look for gene sets that are "active"? Defaults to
#'   `TRUE` if `x` is conformed to a target expression object, else `FALSE`.
#'   [conform()] for further details.
#' @param ... pass through arguments
#' @return A vector of identifiers (or indexes into an expression object,
#'   depending on the `value` argument) for the features in the specified
#'   geneset. `NA` is returned if the geneset is not "active" (ie. listed in
#'   [geneSets()])
#'
#' @examples
#' gdb <- exampleGeneSetDb()
#' fids.gs <- featureIds(gdb, 'c2', 'BIOCARTA_AGPCR_PATHWAY')
#' fids.c2 <- featureIds(gdb, 'c2')
#' fids.all <- featureIds(gdb)
#'
#' vm <- exampleExpressionSet(do.voom=TRUE)
#' gdb <- conform(gdb, vm)
#' ## fewer than before
#' fids.gs2 <- featureIds(gdb, 'c2', 'BIOCARTA_AGPCR_PATHWAY')
#' ## same as before
#' fids.gs3 <- featureIds(gdb, 'c2', 'BIOCARTA_AGPCR_PATHWAY', active.only=FALSE)
#' ## returned as row indices into vm
#' fids.idxs <- featureIds(gdb, 'c2', value='x.idx')
setGeneric("featureIds", signature="x",
           function(x, i, j, value=c('feature_id', 'x.id', 'x.idx'),
                    active.only=is.conformed(x), ...)
             standardGeneric("featureIds"))

#' Fetch the featureIdMap for a `GeneSetDb`
#'
#' The GeneSetDb has an internal data structure that is used to cross reference
#' the feature_id's used in the database construction to the features in the
#' expression object that is used to run GSEA methods against.
#'
#' @exportMethod featureIdMap
#' @param x the object to retrieve the featureIdMap from
#' @param ... pass through arguments
#' @return a data.frame of input feature_id's to conformed id's/rows/etc
#' @examples
#' gdb <- exampleGeneSetDb()
#' vm <- exampleExpressionSet()
#' gdb <- conform(gdb, vm)
#' fmap <- featureIdMap(gdb)
setGeneric("featureIdMap", function(x, ...) standardGeneric("featureIdMap"))

setGeneric("featureIdMap<-", function(x, value)
  standardGeneric("featureIdMap<-")
)


#' Gene Set Collection Metadata
#'
#' Associates key:value metadata to a gene set collection of a [GeneSetDb()].
#'
#' The design of the GeneSetDb is such that we assume that groups of gene sets
#' are usually defined together and will therefore share similar metadata.
#' These groups of gene sets will fall into the same "collection", and,
#' therefore, metadata for particular gene sets are tracked at the collection
#' level.
#'
#' Types of metadata being referred to could be things like the organism
#' that a batch of gene sets were defined in, the type of feature identifiers
#' that a collection of gene sets are using (ie. [GSEABase::EntrezIdentifier()])
#' or a URL pattern that combines the collection,name compound key that one
#' can browse to in order to find out more information about the gene set.
#'
#' There are explicit helper functions that set and get these aforementioned
#' metadata, namely `featureIdType()`, `geneSetCollectionURLfunction()`, and
#' `geneSetURL()`. Aribtrary metadata can be stored at the collection level
#' using the [addCollectionMetadata()] function. More details are provided
#' below.
#'
#' @exportMethod collectionMetadata
#' @rdname collectionMetadata
#'
#' @param x Object to extract the collectionMetadata from
#' @param collection The geneset collection to to query
#' @param name The name of the metadata variable to get the value for
#' @template asdt-param
#' @param ... not used yet
#'
#' @examples
#' gdb <- exampleGeneSetDb()
#'
#' # Gene Set URLs
#' geneSetURL(gdb, 'c2', 'BIOCARTA_AGPCR_PATHWAY')
#' geneSetURL(gdb, c('c2', 'c7'),
#'            c('BIOCARTA_AGPCR_PATHWAY', 'GSE14308_TH2_VS_TH1_UP'))
#'
#' # feature id types
#' featureIdType(gdb, "c2") <- GSEABase::EntrezIdentifier()
#' featureIdType(gdb, "c2")
#'
#' ## Arbitrary metadata
#' gdb <- addCollectionMetadata(gdb, 'c2', 'foo', 'bar')
#' cmh <- collectionMetadata(gdb, 'c2', as.dt = TRUE) ## print this to see
setGeneric(
  "collectionMetadata",
  signature=c("x", "collection", "name"),
  function(x, collection, name, ...) standardGeneric("collectionMetadata"))

#' @section Gene Set URLs:
#'
#' A URL function can be defined per collection that takes the collection,name
#' compound key and generates a URL for the gene set that the user can browse
#' to for futher information. For instance, the
#' `geneSetCollectionURLfunction()` for the MSigDB collections are defined
#' like so:
#'
#' ```
#' url.fn <- function(collection, name) {
#'   url <- 'http://www.broadinstitute.org/gsea/msigdb/cards/%s.html'
#'   sprintf(url, name)
#' }
#' gdb <- getMSigGeneSetDb('H')
#' geneSetCollectionURLfunction(gdb, 'H') <- url.fn
#' ```
#'
#' In this way, a call to `geneSetURL(gdb, 'H', 'HALLMARK_ANGIOGENESIS')`
#' will return
#' http://www.broadinstitute.org/gsea/msigdb/cards/HALLMARK_ANGIOGENESIS.html.
#'
#' This function is vectorized over `i` and `j`
#'
#' @exportMethod geneSetURL
#' @inheritParams featureIds
#' @rdname collectionMetadata
#'
#' @return A character vector of URLs for each of the genesets identified by
#'   `i, j`. `NA` is returned for genesets `i,j` that are not found in `x`.
setGeneric("geneSetURL", signature="x", function(x, i, j, ...)
  standardGeneric("geneSetURL"))


# For some reason @describeIn doesn't work with the
# `geneSetCollectionURLfunction` roxygen docs

#' Get/set the gene set collection url function for a geneset collection
#'
#' Reference [collectionMetadata()] for more info.
#' @rdname geneSetCollectionURLfunction
#' @exportMethod geneSetCollectionURLfunction
setGeneric("geneSetCollectionURLfunction", signature="x", function(x, i, ...)
  standardGeneric("geneSetCollectionURLfunction"))

#' @export
#' @rdname geneSetCollectionURLfunction
setGeneric("geneSetCollectionURLfunction<-",
           signature="x",
           function(x, i, value)
             standardGeneric("geneSetCollectionURLfunction<-"))

#' @section Feature ID Types:
#'
#' When defining a set of gene sets in a collection, the identifiers used must
#' be of the same type. Most often you'll probably be working with Entrez
#' identifiers, simply because that's what most of the annotations work with.
#'
#' As such, you'd define that your collection uses geneset identifiers like
#' so:
#'
#' ```
#' gdb <- getMSigGeneSetDb('H')
#' featureIdType(gdb, 'H') <- GSEABase::ENSEMBLIdentifier()
#' ## or, equivalently (but you don't want to use this)
#' gdb <- addCollectionMetadata(gdb, 'H', 'id_type', GSEABase::ENSEMBLIdentifier())
#' ```
#'
#' @exportMethod featureIdType
#' @rdname collectionMetadata
#' @inheritParams featureIds
setGeneric("featureIdType", signature="x", function(x, i, ...)
  standardGeneric("featureIdType"))

#' @export
#' @rdname collectionMetadata
setGeneric("featureIdType<-", signature="x", function(x, i, value)
  standardGeneric("featureIdType<-"))

#' Fetches information for a gene set
#'
#' @description
#' Gene sets inside a [GeneSetDb()] are indexed by their collection,name
#' compound key. There is no special class to represent an individual gene set.
#' Instead, gene sets are returned as a data.frame, the rows of which enumerate
#' the features that belong to them.
#'
#' When `x` is a [SparrowResult()], this function will append
#' the differential expression statistics for the individual features generated
#' across the contrast that defined `x`.
#'
#' @exportMethod geneSet
#' @rdname geneSet
#'
#' @inheritParams featureIds
#' @param with.feature.map If `TRUE`, then details of the feature mapping
#'   from the original feature_id space to the target feature space are included
#'   (default: `FALSE`).
#' @param ... passed down to inner functinos
#' @template asdt-param
#' @return a `data.(frame|table)` of gene set information. If `x` is a
#'   `SparrowResult` object, then differential expression statistics
#'   are added as columns to this result.
setGeneric("geneSet", signature="x", function(x, i, j, ...)
  standardGeneric("geneSet"))

#' Fetch the active (or all) gene sets from a GeneSetDb or SparrowResult
#'
#' @export
#' @inheritParams featureIds
#' @template asdt-param
#' @return a data.table with geneset information.
#'
#' @rdname geneSets
#' @exportMethod geneSets
#'
#' @examples
#' gdb <- exampleGeneSetDb()
#' gs <- geneSets(gdb)
setGeneric("geneSets", function(x, ...) standardGeneric('geneSets'))


#' Summarize geneset:feature relationships for specified set of features
#'
#' This function creates a geneset by feature table with geneset membership
#' information for the `features` specified by the user. Only the gene sets that
#' have any of the `features` are included in the table returned.
#'
#' @rdname geneSetSummaryByGenes
#' @exportMethod geneSetSummaryByGenes
#'
#' @param x `GeneSetDb` or `SparrowResult`
#' @param features a character vector of featureIds
#' @param with.features Include columns for `features`? If `x` is
#'  is a `GeneSetDb`, these columns are `TRUE`/`FALSE`. If
#'  `x` is a `SparrowResult` object, the values are the logFC of
#'  the feature if present in the gene set, otherwise its `NA`.
#' @param feature.rename if `NULL`, the feature columns are prefixed with
#'   `featureId_`, if `FALSE`, no renaming is done. If `x` is
#'   a `SparrowResult`, then this can be the column name found in
#'   `logFC(x)`, in which case the value for the feature from the given
#'   column name would be used (setting this to `"symbol"`) would be a
#'   common thing to do, for instance.
#' @param ... pass through arguments
#' @template asdt-param
#' @return a data.frame of geneset <-> feature incidence/feature matrix.
#'
#' @examples
#' vm <- exampleExpressionSet(do.voom=TRUE)
#' gdb <- conform(exampleGeneSetDb(), vm)
#' mg <- seas(vm, gdb, design = vm$design, contrast = 'tumor')
#' features <- c("55839", "8522", "29087")
#' gsm.hit <- geneSetSummaryByGenes(gdb, features)
#' gsm.fid <- geneSetSummaryByGenes(mg, features, feature.rename=NULL)
#' gsm.sym <- geneSetSummaryByGenes(mg, features, feature.rename='symbol')
setGeneric("geneSetSummaryByGenes", signature=c("x"),
           function(x, features, with.features = TRUE, feature.rename = NULL,
                    ..., as.dt = FALSE)
             standardGeneric("geneSetSummaryByGenes"))

#' @rdname conform
#' @exportMethod conform
setGeneric("conform", function(x, ...) standardGeneric("conform"))

#' Subset a GeneSetDb to only include geneSets with specified features.
#'
#' @exportMethod subsetByFeatures
#' @rdname subsetByFeatures
#'
#' @param x `GeneSetDb`
#' @param features Character vector of featureIds
#' @param value are you feature id's entered as themselves (`feature_id`), which
#'   is the default, or are you querying by their index into a target expression
#'   object? This is only relevant if you are working with a `conform`-ed
#'   GeneSetDb, and further you as a user won't likely invoke this argument,
#'   but is used internally.
#' @param ... pass through arguments
#' @return A subset of `x` which contains only the geneSets that contain
#'   features found in `featureIds`
#'
#' @examples
#' gdb <- exampleGeneSetDb()
#' features <- c("55839", "8522", "29087")
#' (gdb.sub <- subsetByFeatures(gdb, features))
setGeneric("subsetByFeatures", signature="x",
function(x, features, value=c('feature_id', 'x.id', 'x.idx'), ...)
  standardGeneric("subsetByFeatures"))

#' @exportMethod unconform
#' @rdname conform
setGeneric("unconform", function(x, ...) standardGeneric("unconform"))
