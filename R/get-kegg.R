#' Retrieves the KEGG gene set collection via its REST API
#'
#' Uses [limma::getGeneKEGGLinks()] and [limma::getKEGGPathwayNames()]
#' internally.
#'
#' Currently we just support the pathway database, and only entrez ids.
#'
#' Note that **it is your responsibility** to ensure that you can use the KEGG
#' database according to their licensing requirements.
#'
#' @export
#' @param species `"human"`, `"mouse"` or any of the bioconductor or kegg-style
#'   abbreviations.
#' @param id.type Gene identifiers are returned by the REST service as
#'   entrez identifiers. Set this to `"ensembl"` to translate them internally
#'   using [convertIdentifiers()]. If `species`is not `"human"` or `"mouse"`,
#'   you need to provide an idxref table that works with [convertIdentifiers()].
#' @param ... pass through arguments
#' @return A BiocSet of the kegg stuffs
#' @examples
#' \donttest{
#' # connects to the internet and takes a while
#' mouse.entrez <- getKeggCollection("mouse", id.type = "entrez")
#' human.enrez <- getKeggCollection("human", id.type = "entrez")
#' }
getKeggCollection <- function(species = "human",
                              id.type = c("ensembl", "entrez"),
                              ...) {
  id.type <- match.arg(id.type)
  out <- getKeggGeneSetDb(species, id.type, ...)
  as(out, "BiocSet")
}

#' @describeIn getKeggCollection method that returns a GeneSetDb
#' @export
getKeggGeneSetDb <- function(species = "human",
                             id.type = c("ensembl", "entrez"),
                             ...) {
  sinfo <- species_info(species)
  id.type <- match.arg(id.type)
  if (id.type == "ensembl") {
    stop("sparrow::remapIdentifiers not implemented yet, if you want KEGG ",
         "pathways with ensembl id's from this package, use the pathways ",
         "from the C2 MSigDb collection instead via `getMSigGeneSetDb`")
  }
  gdb <- .get_kegg_pathway_db(sinfo, id.type, ...)

  if (id.type == "entrez") {
    featureIdType(gdb, "KEGG") <- GSEABase::EntrezIdentifier()
  } else {
    gdb <- convertIdentifiers(gdb, from = species, id.type = "ensembl")
    featureIdType(gdb, "KEGG") <- GSEABase::ENSEMBLIdentifier()
  }
  gdb
}


.get_kegg_pathway_db <- function(sinfo, id.type = c("ensembl", "entrez"), ...) {
  if (FALSE) {
    species.code <- "hsa" # human
    species.code <- "mmu" # mouse
    species.code <- "mcf" # cyno
  }
  species.code <- sinfo[["kegg"]]
  id.type <- match.arg(id.type)
  pnames <- limma::getKEGGPathwayNames(species.code, remove.qualifier = TRUE)
  colnames(pnames) <- c("pathway_id", "name")
  membership <- limma::getGeneKEGGLinks(species.code)
  colnames(membership) <- c("feature_id", "pathway_id")

  df. <- merge(membership, pnames, by = "pathway_id")
  df.[["pathway_id"]] <- sub("path:", "", df.[["pathway_id"]])
  df.[["collection"]] <- "KEGG"
  out <- GeneSetDb(df.)

  geneSetCollectionURLfunction(out, "KEGG") <- ".geneSetURL.KEGG"
  out
}

#' @noRd
.geneSetURL.KEGG <- function(collection, name, gdb = NULL, ...) {
  url <- "https://www.kegg.jp/kegg/pathway.html"
  if (test_class(gdb, "GeneSetDb")) {
    gs <- try(geneSet(gdb, collection = collection, name = name), silent = TRUE)
    if (is.data.frame(gs)) {
      pid <- gs$pathway_id[1L]
      url <- paste0("https://www.genome.jp/dbget-bin/www_bget?", pid)
    }
  }
  url
}
