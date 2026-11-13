document <- function(id, content, metadata = list(), score = 0) {
  list(
    id = as.character(id),
    content = as.character(content),
    metadata = as.list(metadata),
    score = as.numeric(score)
  )
}

document_wire <- function(document) {
  out <- list(id = document$id, content = document$content)
  if (length(document$metadata) > 0L) {
    out$metadata <- document$metadata
  }
  if (!identical(document$score, 0) && !is.null(document$score)) {
    out$score <- document$score
  }
  out
}

func_retriever <- function(retrieve) {
  if (!is.function(retrieve)) {
    praxo_error("RETRIEVER_INVALID", "retriever: retrieve must be a function")
  }
  list(retrieve = retrieve)
}

retriever_retrieve <- function(retriever, query, limit) {
  if (!is.list(retriever) || !is.function(retriever$retrieve)) {
    praxo_error("RETRIEVER_INVALID", "retriever: retrieve must be a function")
  }
  retriever$retrieve(as.character(query), as.integer(limit))
}
