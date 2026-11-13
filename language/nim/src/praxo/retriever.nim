import std/tables

import ./errors

type
  Document* = object
    id*: string
    content*: string
    metadata*: Table[string, string]
    score*: float

  Retriever* = proc(query: string, limit: int): seq[Document] {.closure.}

  FuncRetriever* = ref object
    retrieve*: Retriever

proc newDocument*(id: string, content: string,
                  metadata: Table[string, string] = initTable[string, string](),
                  score: float = 0.0): Document =
  Document(id: id, content: content, metadata: metadata, score: score)

proc newFuncRetriever*(retrieve: Retriever): FuncRetriever =
  FuncRetriever(retrieve: retrieve)

proc retrieveDocuments*(retriever: Retriever, query: string,
                        limit: int): seq[Document] =
  if limit < 0:
    raisePraxo("RETRIEVER_INVALID", "retriever: invalid limit")
  if retriever == nil:
    raisePraxo("RETRIEVER_INVALID", "retriever: retrieve is required")
  return retriever(query, limit)

proc retrieveDocuments*(retriever: FuncRetriever, query: string,
                        limit: int): seq[Document] =
  if retriever == nil:
    raisePraxo("RETRIEVER_INVALID", "retriever: retrieve is required")
  return retrieveDocuments(retriever.retrieve, query, limit)
