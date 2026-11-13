module praxo.retriever;

import std.json : JSONType, JSONValue;

import praxo.errors : PraxoError;

struct Document {
    string id;
    string content;
    JSONValue metadata;
    double score;

    this(string id, string content, JSONValue metadata = JSONValue.init,
         double score = 0) {
        this.id = id;
        this.content = content;
        this.metadata = metadata;
        this.score = score;
    }
}

alias Retriever = Document[] delegate(string query, long limit);

JSONValue documentWire(Document document) {
    JSONValue[string] output;
    output["id"] = JSONValue(document.id);
    output["content"] = JSONValue(document.content);
    if (document.metadata.type == JSONType.object && document.metadata.object.length > 0) {
        output["metadata"] = document.metadata;
    }
    if (document.score != 0) {
        output["score"] = JSONValue(document.score);
    }
    return JSONValue(output);
}

Document[] retrieveDocuments(Retriever retriever, string query, long limit) {
    if (retriever is null) {
        throw new PraxoError("RETRIEVER_INVALID",
            "retriever: retrieve must be a function");
    }
    if (limit < 0) {
        throw new PraxoError("RETRIEVER_INVALID", "retriever: invalid limit");
    }
    return retriever(query, limit);
}

class FuncRetriever {
    Retriever fn;

    this(Retriever fn) {
        if (fn is null) {
            throw new PraxoError("RETRIEVER_INVALID",
                "retriever: retrieve must be a function");
        }
        this.fn = fn;
    }

    Document[] retrieve(string query, long limit) {
        return retrieveDocuments(fn, query, limit);
    }
}
