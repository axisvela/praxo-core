use std::io::BufRead;

use crate::errors::{PraxoError, Result};
use crate::model::{Message, Response, Usage};

pub fn parse_stream<R: BufRead>(
    reader: R,
    on_delta: &mut dyn FnMut(&str) -> Result<()>,
) -> Result<Response> {
    let mut content = String::new();
    let mut finish_reason = None;
    let mut done = false;
    for line in reader.lines() {
        let line = line.map_err(|error| PraxoError::new("MODEL_STREAM", error.to_string()))?;
        let Some(data) = line.trim().strip_prefix("data:") else {
            continue;
        };
        let data = data.trim();
        if data == "[DONE]" {
            done = true;
            break;
        }
        let chunk: serde_json::Value = serde_json::from_str(data).map_err(|_| {
            PraxoError::new("MODEL_STREAM", "openai-compatible: invalid stream chunk")
        })?;
        let choice = &chunk["choices"][0];
        if let Some(reason) = choice["finish_reason"].as_str() {
            finish_reason = Some(reason.to_string());
        }
        if let Some(delta) = choice["delta"]["content"].as_str() {
            if !delta.is_empty() {
                content.push_str(delta);
                on_delta(delta)?;
            }
        }
    }
    if !done && finish_reason.is_none() {
        return Err(PraxoError::new(
            "MODEL_STREAM",
            "openai-compatible: stream ended before completion",
        ));
    }
    Ok(Response {
        message: Message::assistant(content, Vec::new()),
        usage: Usage::default(),
        finish_reason,
    })
}
