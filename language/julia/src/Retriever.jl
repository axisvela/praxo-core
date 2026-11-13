module Retrieval

using ..Errors

export Document, FuncRetriever, Retriever, func_retriever, retrieve_documents

const Retriever = Function

struct Document
    id::String
    content::String
    metadata::Dict{String,String}
    score::Float64
end

function Document(id::AbstractString, content::AbstractString,
                  metadata::AbstractDict=Dict{String,String}(), score::Real=0.0)
    return Document(
        String(id),
        String(content),
        Dict{String,String}(String(key) => String(value) for (key, value) in metadata),
        Float64(score),
    )
end

function Document(; id::AbstractString="", content::AbstractString="",
                  metadata::AbstractDict=Dict{String,String}(), score::Real=0.0)
    return Document(id, content, metadata, score)
end

struct FuncRetriever
    retrieve::Retriever
end

func_retriever(retrieve::Retriever) = FuncRetriever(retrieve)

function retrieve_documents(retriever::Retriever, query::AbstractString, limit::Integer)
    limit < 0 && throw(PraxoError("RETRIEVER_INVALID", "retriever: invalid limit"))
    return retriever(String(query), Int(limit))
end

retrieve_documents(retriever::FuncRetriever, query::AbstractString, limit::Integer) =
    retrieve_documents(retriever.retrieve, query, limit)

(r::FuncRetriever)(query::AbstractString, limit::Integer) = retrieve_documents(r, query, limit)

end
