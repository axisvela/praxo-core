use std::collections::BTreeMap;

use crate::errors::Result;

#[derive(Debug, Clone, PartialEq)]
pub struct Document {
    pub id: String,
    pub content: String,
    pub metadata: BTreeMap<String, String>,
    pub score: f64,
}

impl Document {
    pub fn new(id: impl Into<String>, content: impl Into<String>) -> Self {
        Self {
            id: id.into(),
            content: content.into(),
            metadata: BTreeMap::new(),
            score: 0.0,
        }
    }
}

pub trait Retriever: Send + Sync {
    fn retrieve(&self, query: &str, limit: usize) -> Result<Vec<Document>>;
}

pub struct Func<F>(pub F);

impl<F> Retriever for Func<F>
where
    F: Fn(&str, usize) -> Result<Vec<Document>> + Send + Sync,
{
    fn retrieve(&self, query: &str, limit: usize) -> Result<Vec<Document>> {
        (self.0)(query, limit)
    }
}
