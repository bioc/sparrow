#' Creates a GeneSetDb from a variety of different types of inputs.
#'
#' @description
#' The GeneSetDb class serves the same purpose as the
#' [GSEABase::GeneSetCollection()] class does: it acts as a centralized
#' object to hold collections of Gene Sets. The reason for its existence is
#' because there are things that I wanted to know about my gene set
#' collections that weren't easily inferred from what is essentially a
#' "list of GeneSets" that is the `GeneSetCollection` class.
#'
#' Gene Sets are internally represented by a `data.table` in "a tidy"
#' format, where we minimally require non `NA` values for the following
#' three `character` columns:
#'
#' * collection
#' * name
#' * feature_id
#'
#' The (`collection`, `name`) compound key is the primary key of a gene set.
#' There will be as many entries with the same (`collection`, `name`) as there
#' are genes/features in that set.
#'
#' The `GeneSetDb` tracks metadata about genesets at **the collection**
#' level. This means that we assume that all of the `feature_id`'s used
#' within a collection use the same type of feature identifier (such as
#' a [GSEABase::EntrezIdentifier()], were defined in the same organism,
#' etc.
#'
#' **Please refer to the "GeneSetDb" section of the vignette** for more
#' details regarding the construction and querying of a `GeneSetDb` object.
#'
#' @section GeneSetDb Construction:
#'
#' The `GeneSetDb()` constructor is sufficiently flexible enough to create
#' a `GeneSetDb` object from a variety of formats that are commonly used
#' in the bioconductor echosystem, such as:
#'
#' * [GSEABase::GeneSetCollection()]: If you already have a `GeneSetCollection`
#'   on your hands, you can simply pass it to the `GeneSetDb()` constructor.
#' * list of ids: This format is commonly used to define gene sets in the
#'   edgeR/limma universe for testing with camera, roast, romer, etc. The names
#'   of the list items are the gene set names, and their values are a character
#'   vector of gene identifiers. When it's a single list of lists, you must
#'   provide a value for `collectionName`. You can embed multiple
#'   collections of gene sets by having a three-deep list-of-lists-of-ids.
#'   The top level list define the different collections, the second level
#'   are the genesets, and the third level are the feature identifiers for
#'   each gene set. See the examples for clarification.
#' * a `data.frame`-like object: To keep track of your own custom gene sets, you
#'   have probably realized the importance of maintaing your own sanity, and
#'   likely have gene sets organized in a table like object that has something
#'   like the `collection`, `name`, and `feature_id` required for a `GeneSetDb`.
#'   Simply rename the appropriate columns to the ones prescribed here, and pass
#'   that into the constructor. Any other additional columns (symbol, direction,
#'   etc.) will be copied into the `GeneSetDb`.
#'
#' @section Interrogating a GeneSetDb:
#'
#' You might wonder what gene sets are defined in a `GeneSetDb`: see
#' the [geneSets()] function.
#'
#' Curious about what features are defined in your `GeneSetDb`? See
#' the [featureIds()] function.
#'
#' Want the details of a particular gene set? Try the [geneSet()] function.
#' This will return a `data.frame` of the gene set definition. Calling
#' [geneSet()] on a [SparrowResult()] will return the same `data.frame` along
#' with the differential expression statistics for the individual members of the
#' geneSet across the contrast that was tested in the [seas()] call that
#' created the [SparrowResult()].
#'
#' @section GeneSetDb manipulation:
#'
#' You can subset a GeneSetDb to include a subset of genesets defined in it.
#' To do this, you need to provide an indexing vector that is as long as
#' `length(gdb)`, ie. the number of gene sets defined in GeneSetDb. You
#' can construct such a vector by performing your boolean logic over the
#' `geneSets(gdb)` table.
#'
#' Look at the Examples section to see how this works, where we take the
#' MSIgDB c7 collection (aka. "ImmuneSigDB") and only keep gene sets that
#' were defined in experiments from mouse.
#'
#' @rdname GeneSetDb-class
#' @aliases GeneSetDb
#' @export
#' @seealso `?conversion`
#'
#' @param x A `GeneSetCollection`, a "two deep" list of either
#'   `GeneSetCollection`s or lists of character vectors, which are
#'   the gene identifers. The "two deep" list represents the different
#'   collections (top level) at the top level, and each such list is a named
#'   list itself, which represents the gene sets in the given collection.
#' @param featureIdMap A data.frame with  2 character columns. The first
#'   column is the ids of the genes (features) used to identify the genes in
#'   `gene.sets`, the second second column are IDs that this should be mapped
#'   to. Useful for testing probelevel microarray data to gene level gene set
#'   information.
#' @param collectionName If `x` represents a singular collection, ie.
#'   a single `GeneSetCollection` or a "one deep" (named (by geneset))
#'   list of genesets, then this parameter provides the name for the
#'   collection. If `x` is multiple collections, this can be character
#'   vector of same length with the names. In all cases, if a collection name
#'   can't be defined from this, then collections will be named anonymously.
#'   If a value is passed here, it will overide any names stored in the list of
#'   `x`.
#' @param ... these aren't used for anything in particular, but are here to
#'   catch extra arguments that may get passed down if this function is part
#'   of some call chain.
#' @return A GeneSetDb object
#' @examples
#' ## exampleGeneSetDF provides gene set definitions in "long form". We show
#' ## how this can easily turned into a GeneSetDb from this form, or convert
#' ## it to other forms (list of features, or list of list of features) to
#' ## do the same.
#' gs.df <- exampleGeneSetDF()
#' gdb.df <- GeneSetDb(gs.df)
#'
#' ## list of ids
#' gs.df$key <- encode_gskey(gs.df)
#' gs.list <- split(gs.df$feature_id, gs.df$key)
#' gdb.list <- GeneSetDb(gs.list, collectionName='custom-sigs')
#'
#' ## A list of lists, where the top level list splits the collections.
#' ## The name of the collection in the GeneSetDb is taken from this top level
#' ## hierarchy
#' gs.lol <- as.list(gdb.df, nested=TRUE) ## examine this list-of lists
#' gdb.lol <- GeneSetDb(gs.lol) ## note that collection is set propperly
#'
#' ## GeneSetDb Interrogation
#' gsets <- geneSets(gdb.df)
#' nkcells <- geneSet(gdb.df, 'cellularity', 'NK cells')
#' fids <- featureIds(gdb.df)
#'
#' # GeneSetDb Manipulation ....................................................
#' # Subset down to only t cell related gene sets
#' gdb.t <- gdb.df[grepl("T cell", geneSets(gdb.df)$name)]
#' gdb.t
GeneSetDb <- function(x, featureIdMap = NULL, collectionName = NULL, ...) {
  UseMethod("GeneSetDb", x)
}

#' @noRd
#' @export
GeneSetDb.default <- function(x, featureIdMap = NULL, collectionName = NULL,
                              ...) {
  stop("No GeneSetDb constructor method defined for: ", class(x)[1L])
}

#' @noRd
#' @export
GeneSetDb.GeneSetDb <- function(x, featureIdMap = NULL, collectionName = NULL,
                                ...) {
  x
}

#' This is the main worker function. We'll transform all other inputs to a
#' data.frame reresentation and then finish things off here.
#'
#' @noRd
#' @export
#' @method GeneSetDb data.frame
GeneSetDb.data.frame <- function(x, featureIdMap = NULL, collectionName = NULL,
                                 ...) {
  stopifnot(is.data.frame(x) && nrow(x) > 0)
  proto <- new("GeneSetDb")
  x <- setDT(as.data.frame(copy(x)))

  if (!'collection' %in% names(x)) {
    if (!is.character(collectionName) &&
        !length(collectionName) %in% c(1L, nrow(x))) {
      stop("If no `collection` column is provided in `x`, ",
           "collectionName must be well defined")
    }
    x[, collection := collectionName]
  }

  if (!"feature_id" %in% colnames(x)) {
    if ("featureId" %in% colnames(x)) {
      setnames(x, "featureId", "feature_id")
    }
  }

  req.cols <- key(proto@db)
  cols.missed <- setdiff(req.cols, names(x))
  if (length(cols.missed)) {
    stop("The following columns are missing from `x`:\n ",
         paste(cols.missed, collapse=", "))
  }

  if (any(is.na(x[["feature_id"]]))) {
    message("Removing NA feature_id's from input")
    x <- x[!is.na(feature_id)]
  }

  if (is.factor(x[["collection"]])) x[, collection := as.character(collection)]
  if (is.factor(x[["name"]])) x[, name := as.character(name)]
  if (!is.character(x[["feature_id"]])) x[, feature_id := as.character(feature_id)]

  x <- unique(x, by = req.cols)
  db <- x[, key(proto@db), with = FALSE]
  setkeyv(db, key(proto@db))
  tbl <- init.gsd.table.from.db(db)

  meta <- tbl[, {
    list(name = c("url_function"), value = list(".geneSetURL.NA"))
  }, by = 'collection']
  setkeyv(meta, key(proto@collectionMetadata))

  if (is.null(featureIdMap)) {
    .ids <- unique(db$feature_id)
    featureIdMap <- data.table(feature_id = .ids, x.id = .ids, x.idx = NA_integer_)
    setkeyv(featureIdMap, key(featureIdMap(proto, as.dt = TRUE)))
  }

  gdb <- .GeneSetDb(table = tbl,
                    db = db,
                    featureIdMap = featureIdMap,
                    collectionMetadata = meta)

  # If the input data.frame has extra columns, we will either add them as
  # annotations to the individual genes in the geneset, or as metadata for the
  # geneset as a whole. We disambiguate between gene-level annotation and
  # gene-set level annotations for each column be teseting if there is only one
  # value for the column within all collection,name groupings. If this is TRUE,
  # then the column is a geneset-level annotation, otherwise it's a gene-level
  # (WITHIN geneset) annotation
  add.cols <- setdiff(names(x), req.cols)

  if (length(add.cols)) {
    is.gs.level <- local({
      # test if every value of each extra meta column (add.cols) is equal to
      # the first element (ie. they are all the same)
      xtype <- x[, {
        lapply(.SD, function(vals) {
          # test for equality (==) doesn't work if vals[1L] is NA or NULL
          # all(vals == vals[1L])
          if (is.na(vals[1L])) {
            all(is.na(vals))
          } else if (is.null(vals[1L])) {
            # is this possible?
            all(is.null(vals))
          } else {
            all(!is.na(vals) & vals == vals[1L])
          }
        })
      }, by = c("collection", "name"), .SDcols = add.cols]
      sapply(xtype[, add.cols, with = FALSE], all)
    })
    gs.level <- names(is.gs.level)[is.gs.level]
    gn.level <- names(is.gs.level)[!is.gs.level]
    if (length(gn.level)) {
      ganno.cnames <- c(req.cols, gn.level)
      ganno <- x[, ganno.cnames, with = FALSE]
      db <- merge(gdb@db, ganno, by=req.cols, all.x=TRUE)
      db0 <- setkeyv(copy(gdb@db), req.cols)
      setkeyv(db, req.cols)
      gn.kosher <- all.equal(db0, db[, req.cols, with = FALSE],
                             check.attributes = FALSE)
      if (!gn.kosher) {
        warning("Something unexpected happened merging more feature metadata",
                immediate.=TRUE)
      }
      gdb@db <- db
    }
    if (length(gs.level)) {
      gs.anno <- x[, c(key(proto@table), gs.level), with = FALSE]
      # quick way to get first row of each group without materializing .SD
      idxs <- gs.anno[, list(idx = .I[1L]), by = key(proto@table)]
      gs.anno <- gs.anno[idxs$idx]
      gdb <- addGeneSetMetadata(gdb, gs.anno)
    }
  }

  setkeyv(gdb@db, key(proto@db))
  setkeyv(gdb@table, key(proto@table))
  setkeyv(gdb@featureIdMap, key(proto@featureIdMap))
  setkeyv(gdb@collectionMetadata, key(proto@collectionMetadata))
  gdb
}

#' Creates a GeneSetDb out of a list of vectors, where each vector defines
#' a geneset. This is the format that is used (mostly) in the limma/edgeR
#' user guides for running camera, fry, and roast.
#'
#' This function will create a data.frame where the geneset name is `names(x)`
#' and the elements of the geneset are the individual elements of the list.
#'
#' @noRd
#' @export
GeneSetDb.list <- function(x, featureIdMap = NULL, collectionName = NULL, ...) {
  if (!is.list(x) || length(x) == 0L) {
    stop("A non-empty list is required for this function")
  }
  # Ensure all elements of the list are of the same type
  if (!all(sapply(x, function(y) is(y, class(x[[1L]]))))) {
    stop("All elements of list are not of the same class")
  }
  if (is(x[[1]], 'GeneSetCollection')) {
    if (is.null(collectionName)) {
      collectionName <- names(x)
    }
    out <- .GeneSetDb.list.of.GeneSetCollections(x, featureIdMap,
                                                 collectionName)
    return(out)
  }

  # Is this just a "one deep" list of genesets? If so, let's wrap it in a list
  if (is.single.list.of.feature.vectors(x)) {
    x <- list(x)
  }
  if (is.null(collectionName)) {
    collectionName <- names(x)
  }
  if (is.null(collectionName)) {
    collectionName <- sprintf('anon_collection_%d', seq(x))
  }
  if (!is.character(collectionName)) {
    stop("Character vector expected for `collectionName`")
  }
  if (length(collectionName) != length(x)) {
    stop("length(collectionName) != length(x)")
  }
  names(x) <- collectionName

  db <- init.gsd.db.from.list.of.lists(x)
  GeneSetDb(db, featureIdMap = featureIdMap, ...)
}

#' @noRd
#' @export
GeneSetDb.GeneSetCollection <- function(x, featureIdMap = NULL,
                                        collectionName = 'anon_collection',
                                        ...) {
  assert_string(collectionName)
  # Create a list of GeneSetCollections
  gsc.list <- setNames(list(x), collectionName)
  .GeneSetDb.list.of.GeneSetCollections(gsc.list, featureIdMap, collectionName)
}

#' @noRd
#' @export
GeneSetDb.BiocSet <- function(x, featureIdMap = NULL,
                              collectionName = "BiocSet Collection", ...) {
  tbl <- x@elementset
  names(tbl) <- c("feature_id", "name")
  GeneSetDb(tbl, featureIdMap = NULL, collectionName = collectionName, ...)
}

#' Create a GeneSetDb from a named list of GeneSetCollection objects, each
#' each GeneSetCollection of the list represents its own "collection" group
#' in a GeneSetDb.
#'
#' @noRd
#' @importFrom GSEABase setName geneIds geneIdType
.GeneSetDb.list.of.GeneSetCollections <- function(x, featureIdMap = NULL,
                                                  collectionName = names(x),
                                                  ...) {
  stopifnot(is.list(x))
  stopifnot(length(x) > 0)
  stopifnot(all(sapply(x, is, 'GeneSetCollection')))
  if (is.null(collectionName)) {
    collectionName <- sprintf('anon_collection_%d', seq(x))
  }
  if (!is.character(collectionName) && length(collectionName) != length(x)) {
    stop("Invalid value for `collectionName`")
  }

  lol <- lapply(seq_len(length(x)), function(i) {
    gsc.name <- collectionName[i]
    gsc <- x[[i]]
    id.list <- lapply(gsc, geneIds)
    org <- unique(sapply(gsc, GSEABase::organism))
    id.type <- unique(sapply(gsc, function(x) class(geneIdType(x))))
    if (length(org) > 1) {
      warning("multiple organisms defined in geneset collection: ", gsc.name,
              immediate.=TRUE)
    }
    if (length(id.type) > 1) {
      stop("different idtypes used in genesets: ", paste(id.type, collapse=','))
    }
    setNames(id.list, sapply(gsc, setName))
  })
  names(lol) <- collectionName
  GeneSetDb(lol, featureIdMap, collectionName)
}

setAs("GeneSetCollection", "GeneSetDb", function(from) GeneSetDb(from))
setAs("BiocSet", "GeneSetDb", function(from) {
  # There's a lot we can transfer over, including which sets are "active"
  # and whatnot. For now, let's just get the basics in.
  GeneSetDb(from)
})

## Constructor Helper Functions ------------------------------------------------

#' Turns a list of lists GeneSetDb representation into a data.frame
#' @noRd
init.gsd.db.from.list.of.lists <- function(x) {
  proto <-.GeneSetDb()
  ## Ensure x is list of list of geneset features
  x <- validate.gene.sets.input(x)

  ## "melt" the x list-of-lists Create internal db data.table that
  ## stores the "pristine" geneset membership information passed into this
  ## function via `x`.
  db <- local({
    groups <- lapply(names(x), function(g.name) {
      members <- lapply(names(x[[g.name]]), function(id) {
        ids <- unique(x[[g.name]][[id]])
        data.table(collection=g.name, name=id, feature_id=ids)
      })
      rbindlist(members)
    })
    setkeyv(rbindlist(groups), key(proto@db))
  })

  db
}

#' @noRd
init.gsd.table.from.db <- function(db) {
  proto <- .GeneSetDb()
  out <- db[, list(active=FALSE, N=.N, n=NA_integer_), by=c('collection', 'name')]
  setkeyv(out, key(proto@table))
}


setMethod("show", "GeneSetDb", function(object) {
  proto <- .GeneSetDb()
  msg <- paste("GeneSetDb with %d defined genesets across %d collections",
               "(%d gene sets are active)")
  msg <- sprintf(msg,
                 nrow(unique(object@db, by=c('collection', 'name'))),
                 length(unique(object@db$collection)),
                 sum(object@table$active))
  is.conf <- paste("  Conformed:", ifelse(is.conformed(object), 'yes', 'no'))
  hr <- paste(rep("=", nchar(msg)), collapse='')
  hr.sub <- gsub('=', '-', hr)
  cat(hr, "\n", msg, "\n", is.conf, "\n", hr.sub, "\n", sep="")
  print(geneSets(object, as.dt=TRUE))
  cat(hr.sub, "\n", msg, "\n", is.conf, "\n", hr, "\n", sep="")
})

## -----------------------------------------------------------------------------
## Functions to check validity of GeneSetDb
setValidity("GeneSetDb", function(object) {
  proto <- .GeneSetDb()

  ## Get classes of the slots
  sclass <- sapply(slotNames(proto), function(x) class(slot(proto, x))[1L])

  ## Check all data.tables to ensure that they have a superset of the columns
  ## to the comparable prototype versions *and* they share the same defined
  ## keys.
  dt.errs <- sapply(names(sclass)[sclass == 'data.table'], function(s) {
    check.dt(slot(object, s), slot(proto, s))
  }, simplify=FALSE)

  u <- unlist(dt.errs)
  if (is.character(u)) {
    return(u)
  }

  cm.errs <- .validateCollectionMetadata(object)
  if (!isTRUE(cm.errs)) {
    return(cm.errs)
  }

  ## ---------------------------------------------------------------------------
  ## Further check @db slot:
  ## 1. ensure all features in @db have a row in the @featureIdMap
  if (!all(object@db$feature_id %in% featureIdMap(object, as.dt=TRUE)$feature_id)) {
    return("Some @db$feature_id's are not in featureIdMap(object)$feature_id")
  }
  if (any(is.na(object@db$feature_id))) {
    return("NA's not permitted in @db$feature_id")
  }
  ## Ensure that the collection,id combination is unique in @table
  if (any(duplicated(object@table, by=key(proto@table)))) {
    return("Duplicated gene set entries in @table")
  }

  ## Ensure that that collection,id,feature_id are unique in @db
  if (any(duplicated(object@db, by=c('collection', 'name', 'feature_id')))) {
    return("Duplicated collection,id,feature_id in @db")
  }

  TRUE
})

#' Checks validaty of collectionMetadata of a GeneSetDb
#'
#' This function is for internal use only
#'
#' The following assertions are tested:
#'
#' * All (collection,name) entries are unique.
#' * All collections have a url_function.
#' * The collections that are listed in collectionMetadata have >= 1 defined
#'   genesets in `geneSets(object)`
#'
#' @noRd
#' @param object A \code{GeneSetDb}
#' @return TRUE if the collectionMetadata is kosher, otherwise a character
#'   vector of errors.
.validateCollectionMetadata <- function(object) {
  ## ---------------------------------------------------------------------------
  ## Check the collectionMetadata bits
  ## ---------------------------------------------------------------------------

  ## Get geneSet information from GeneSetDb to ensure we have collectionMetadata
  ## for all the genesets in our object
  gs.info <- geneSets(object, active.only=FALSE, as.dt=TRUE)[, {
    list(count=.N)
  }, keyby='collection']

  ##
  ## 1. Ensure that all collection,name entries are unique
  dupd <- duplicated(object@collectionMetadata, by=c('collection', 'name'))
  if (any(dupd)) {
    return('Duplicated (collection,name) entries in @collectionMetadata')
  }

  # NOTE: remove count collectionMetadata
  ## 2. Collect information about required metadata entries for each collection,
  ##    ie. the count of genesets in the collection and their url_function
  # name <- value <- NULL # silence R CMD check NOTEs
  cm.info <- object@collectionMetadata[, {
    is.url.fn <- which(name == 'url_function')
    # is.count <- which(name == 'count')
    if (length(is.url.fn) == 0) {
      url.fn.status <- 'not-defined'
    } else {
      fn <- value[[is.url.fn]]
      if (!is.function(fn)) {
        url.fn.status <- 'not-a-function'
      } else if (length(formalArgs(fn)) < 3) {
        url.fn.status <- 'not-enough-args'
      } else {
        url.fn.status <- 'ok'
      }
    }
    # if (length(is.count) == 0) {
    #   count <- NA_integer_
    # } else {
    #   count <- value[[is.count]]
    # }
    # list(count=count, url.fn.stauts=url.fn.status)
    list(url.fn.stauts = url.fn.status)
  }, keyby='collection']

  ## 3. Minimally ensure we have metadata for all genesets
  if (!(nrow(gs.info) == nrow(cm.info) ||
        all(gs.info$collection == cm.info$collection) ||
        all(gs.info$name == cm.info$name))) {
    msg <- paste('Number of defined collections in geneSets() does not match',
                 'defined collections in collectionMetadata')
    return(msg)
  }

  ## 4. Ensure url functions are kosher
  bad.fns <- cm.info$url.fn.status != 'ok'
  if (any(bad.fns)) {
    msg <- paste('bad url fns:\n',
                 paste(sprintf('  %s:%s', cm.info$collection[bad.fns],
                               cm.info$url.fn.status[bad.fns]),
                       collapse='\n'))
    return(msg)
  }

  # NOTE: remove count collectionMetadata
  ## 5. Check that counts match per geneset
  # if (any(gs.info$count != cm.info$count)) {
  #   msg <- paste('gene set counts per collection do not match')
  #   return(msg)
  # }

  TRUE
}

## -----------------------------------------------------------------------------
## Helper functions to enable setting up of the GeneSetDb


#' @noRd
is.single.list.of.feature.vectors <- function(x) {
  is.list(x) && all(sapply(x, is.character))
}

#' @noRd
validate.gene.sets.input <- function(gene.sets) {
  ## Did the user only enter a single list of character vectors? We need to
  ## change this into a list of lists
  if (is.single.list.of.feature.vectors(gene.sets)) {
    ## make this into a list of lists
    gene.sets <- list(undef=gene.sets)
  }

  ## is each top level entry a list?
  top.are.lists <- sapply(gene.sets, is.list)
  if (!all(top.are.lists)) {
    stop("The gene.sets input should be a list of lists")
  }

  ## Are these specified as characters?
  xxx <- unlist(gene.sets)
  if (!is.character(xxx)) {
    stop("Identifiers used in gene.set list must be characters")
  }

  groups <- names(gene.sets)
  if (!is.character(groups) || any(duplicated(groups))) {
    stop("names() of gene.sets list must be set and unique")
  }

  bad.gs <- !sapply(gene.sets, is.single.list.of.feature.vectors)
  if (any(bad.gs)) {
    report <- paste(head(which(bad.gs), 10), collapse=',')
    if (sum(bad.gs) > 10) {
      report <- paste0(report, ',...')
    }
    stop("These gene.set lists are bad. Are IDs characters(?): ", report)
  }
  gene.sets
}
