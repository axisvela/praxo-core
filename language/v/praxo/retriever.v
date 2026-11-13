module praxo

pub struct Document {
pub:
	id       string
	content  string
	metadata map[string]string
	score    f64
}

pub type Retriever = fn (query string, limit int) ![]Document

pub struct FuncRetriever {
pub:
	retrieve Retriever
}

pub fn document(id string, content string) Document {
	return Document{id: id, content: content}
}

pub fn document_scored(id string, content string, metadata map[string]string, score f64) Document {
	return Document{id: id, content: content, metadata: metadata, score: score}
}

pub fn func_retriever(retrieve Retriever) FuncRetriever {
	return FuncRetriever{retrieve: retrieve}
}

pub fn retrieve_documents(retriever Retriever, query string, limit int) ![]Document {
	if limit < 0 {
		return praxo_error('RETRIEVER_INVALID', 'retriever: invalid limit')
	}
	return retriever(query, limit)
}

pub fn (retriever FuncRetriever) retrieve_documents(query string, limit int) ![]Document {
	return retrieve_documents(retriever.retrieve, query, limit)
}
