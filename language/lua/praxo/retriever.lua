local errors = require("praxo.errors")

local M = {}

function M.document(id, content, metadata, score)
  return {
    id = tostring(id),
    content = tostring(content),
    metadata = metadata or {},
    score = score or 0,
  }
end

function M.document_wire(document)
  local out = { id = document.id, content = document.content }
  if next(document.metadata or {}) ~= nil then
    out.metadata = document.metadata
  end
  if document.score ~= nil and document.score ~= 0 then
    out.score = document.score
  end
  return out
end

function M.func_retriever(retrieve)
  if type(retrieve) ~= "function" then
    errors.raise("RETRIEVER_INVALID", "retriever: retrieve must be a function")
  end
  return { retrieve = retrieve }
end

function M.retriever_retrieve(retriever, query, limit)
  if type(retriever) ~= "table" or type(retriever.retrieve) ~= "function" then
    errors.raise("RETRIEVER_INVALID", "retriever: retrieve must be a function")
  end
  return retriever.retrieve(tostring(query), math.tointeger(limit) or limit)
end

return M
