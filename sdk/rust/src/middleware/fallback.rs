use std::sync::Arc;

use crate::errors::Result;
use crate::middleware::{ModelHandler, ModelMiddleware};
use crate::model::{Model, Request, Response};

pub fn fallback_model(fallback: Option<Arc<dyn Model>>) -> ModelMiddleware {
    Box::new(move |next: ModelHandler| {
        let fallback = fallback.clone();
        Box::new(move |request: &Request| {
            match next(request) {
                Ok(response) => Ok(response),
                Err(primary) => {
                    let Some(fallback) = &fallback else {
                        return Err(primary);
                    };
                    match fallback.generate(request) {
                        Ok(response) => Ok(response),
                        Err(_) => Err(primary),
                    }
                }
            }
        })
    })
}

pub fn fallback_with_content(content: String) -> ModelMiddleware {
    fallback_model(Some(Arc::new(StaticModel { content })))
}

struct StaticModel {
    content: String,
}

impl Model for StaticModel {
    fn generate(&self, _request: &Request) -> Result<Response> {
        Ok(Response {
            message: crate::model::Message::assistant(self.content.clone(), Vec::new()),
            ..Response::default()
        })
    }
}
