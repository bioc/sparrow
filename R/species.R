#' Match a species query to the regularized species info.
#'
#' @export
#' @param query the species name to lookup, if `NULL` (default), returns the
#'   internal species info table, otherwise the row of the table that matches
#'   `query`.
#' @param ... pass through
#' @return a data.frame of species-related information that is used to fetch
#'   appropriate annotation files and conversion functions between species
#'   for gene identifiers, and such.
#' @examples
#' species_info()
#' species_info("human")
species_info <- function(query = NULL, ...) {
  info <- read.csv(
    stringsAsFactors = FALSE,
    system.file("extdata", "species-info.csv", package = "sparrow"))
  if (is.null(query)) return(info)
  query <- assert_string(query)
  query <- gsub(" +", "_", tolower(query))
  idx <- NA
  for (cname in names(info)) {
    vals <- tolower(info[[cname]])
    vals <- gsub(" +", "_", vals)
    idx <- match(query, vals)
    if (!is.na(idx)) break
  }
  if (is.na(idx)) {
    stop("No match found for query: ", query)
  }
  as.list(info[idx,])
}

#' @noRd
resolve.species <- function(x) {
  stopifnot(is.character(x) && length(character) == 1L)
  xx <- tolower(x)
  opts <- c(
    fly="Drosophila_melanogaster",
    human='Homo_sapiens',
    homo_sapiens='Homo_sapiens',
    hsa='Homo_sapiens',
    ## mouse
    mouse='Mus_musculus',
    mus_musculus='Mus_musculus',
    mmu='Mus_musculus')
  out <- opts[xx]
  if (is.na(out)) {
    stop("Illegal species value: ", x)
  }
  out
}
