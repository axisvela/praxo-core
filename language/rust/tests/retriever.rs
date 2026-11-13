use praxo_core::retriever::{Document, Func, Retriever};

#[test]
fn function_retriever_forwards_query_and_limit() {
    let retriever = Func(|query: &str, limit: usize| {
        Ok(vec![Document::new(
            "doc-1",
            format!("{query}:{limit}"),
        )])
    });
    let documents = retriever.retrieve("hello", 3).expect("retrieve");
    assert_eq!(documents.len(), 1);
    assert_eq!(documents[0].id, "doc-1");
    assert_eq!(documents[0].content, "hello:3");
}
