use std::sync::Arc;

use serde_json::{Map, Value};

use crate::agent::RunResult;
use crate::errors::PraxoError;
use crate::middleware::{
    fallback_with_content, CallLimitMiddleware, Middleware, MiddlewareToolCall, ModelCall,
    PiiMiddleware, PiiRedactor, RunState, StructuredOutput, ToolResult, ToolSelectionMiddleware,
    ToolSelector,
};
use crate::model::{Request, ToolCall, ToolSpec, Usage};

pub fn run_middleware(vector: &Value) -> Result<(), String> {
    let input = &vector["input"];
    let expect = &vector["expect"];
    match input["operation"].as_str().unwrap_or("") {
        "pii" => {
            let got = PiiRedactor::defaults().redact(input["text"].as_str().unwrap_or(""));
            check(
                Value::String(got.clone()) == expect["text"],
                format!("text: got {got}"),
            )
        }
        "pii-value" => {
            let middleware = PiiMiddleware::new(PiiRedactor::defaults());
            let mut result = ToolResult {
                value: input["value"].clone(),
                error: None,
            };
            middleware
                .after_tool(&tool_call("r1", "s1", "echo"), &mut result)
                .map_err(|error| error.message)?;
            check(result.value == expect["value"], "value mismatch".to_string())
        }
        "structured" => {
            let mut output = StructuredOutput::new(
                input["schema"].as_object().cloned().unwrap_or_default(),
            )
            .with_repairs(input["maxRepairs"].as_u64().unwrap_or(0) as usize);
            if let Some(repair) = input["repairOutput"].as_str() {
                let repair = repair.to_string();
                output = output.with_repairer(move |_, _| Ok(repair.clone()));
            }
            let mut result = RunResult {
                run_id: "r1".to_string(),
                output: input["output"].as_str().unwrap_or("").to_string(),
                steps: 0,
                usage: Usage::default(),
            };
            match output.apply(&mut result) {
                Ok(()) => {
                    check(
                        expect["ok"].as_bool().unwrap_or(false),
                        "expected a structured output error".to_string(),
                    )?;
                    check(
                        Value::String(result.output.clone()) == expect["output"],
                        format!("output: got {}", result.output),
                    )
                }
                Err(error) => {
                    check(
                        !expect["ok"].as_bool().unwrap_or(false),
                        error.message.clone(),
                    )?;
                    check(
                        Some(error.code) == expect["errorCode"].as_str(),
                        format!("errorCode: got {}", error.code),
                    )
                }
            }
        }
        "call-limit" => {
            let middleware = CallLimitMiddleware::new(
                input["modelLimit"].as_u64().unwrap_or(0) as usize,
                input["toolLimit"].as_u64().unwrap_or(0) as usize,
            );
            middleware
                .before_run(&RunState {
                    run_id: "r1".to_string(),
                    prompt: String::new(),
                })
                .map_err(|error| error.message)?;
            let mut outcomes = Vec::new();
            for kind in input["calls"].as_array().cloned().unwrap_or_default() {
                let result = match kind.as_str().unwrap_or("") {
                    "model" => middleware.before_model(&mut ModelCall {
                        run_id: "r1".to_string(),
                        session_id: "s1".to_string(),
                        request: Request::default(),
                        skip: false,
                        response: None,
                    }),
                    "tool" => {
                        let mut call = tool_call("r1", "s1", "echo");
                        middleware.before_tool(&mut call)
                    }
                    _ => Err(PraxoError::new(
                        "CONFORMANCE",
                        "unknown call kind",
                    )),
                };
                outcomes.push(Value::String(match result {
                    Ok(()) => "ok".to_string(),
                    Err(error) => error.code.to_string(),
                }));
            }
            check(
                Value::Array(outcomes) == expect["outcomes"],
                "outcomes mismatch".to_string(),
            )
        }
        "tool-selection" => {
            let selected: Vec<String> = input["selected"]
                .as_array()
                .cloned()
                .unwrap_or_default()
                .into_iter()
                .filter_map(|item| item.as_str().map(str::to_string))
                .collect();
            let middleware =
                ToolSelectionMiddleware::new(Arc::new(FixedSelector { names: selected }));
            let tools: Vec<ToolSpec> = input["tools"]
                .as_array()
                .cloned()
                .unwrap_or_default()
                .into_iter()
                .filter_map(|item| item.as_str().map(|name| ToolSpec {
                    name: name.to_string(),
                    description: String::new(),
                    parameters: None,
                    risk: None,
                }))
                .collect();
            let mut call = ModelCall {
                run_id: "r1".to_string(),
                session_id: "s1".to_string(),
                request: Request {
                    tools,
                    ..Request::default()
                },
                skip: false,
                response: None,
            };
            middleware
                .before_model(&mut call)
                .map_err(|error| error.message)?;
            let advertised: Vec<Value> = call
                .request
                .tools
                .iter()
                .map(|spec| Value::String(spec.name.clone()))
                .collect();
            check(
                Value::Array(advertised) == expect["advertised"],
                "advertised mismatch".to_string(),
            )?;
            let mut tool = tool_call("r1", "s1", input["requested"].as_str().unwrap_or(""));
            let reject = match middleware.before_tool(&mut tool) {
                Ok(()) => "ok".to_string(),
                Err(error) => error.code.to_string(),
            };
            check(
                Value::String(reject.clone()) == expect["reject"],
                format!("reject: got {reject}"),
            )
        }
        "fallback" => {
            let handler = fallback_with_content(
                input["fallbackContent"].as_str().unwrap_or("").to_string(),
            )(Box::new(|_| {
                Err(PraxoError::new("PRIMARY_FAILED", "primary failed"))
            }));
            let response = handler(&Request::default()).map_err(|error| error.message)?;
            check(
                response.message.content.unwrap_or_default()
                    == input["fallbackContent"].as_str().unwrap_or(""),
                "output mismatch".to_string(),
            )
        }
        other => Err(format!("unknown middleware operation {other}")),
    }
}

struct FixedSelector {
    names: Vec<String>,
}

impl ToolSelector for FixedSelector {
    fn select(&self, _query: &str, _tools: &[ToolSpec]) -> crate::errors::Result<Vec<String>> {
        Ok(self.names.clone())
    }
}

fn tool_call(run_id: &str, session_id: &str, name: &str) -> MiddlewareToolCall {
    MiddlewareToolCall {
        run_id: run_id.to_string(),
        session_id: session_id.to_string(),
        call: ToolCall {
            id: "c".to_string(),
            name: name.to_string(),
            arguments: Map::new(),
        },
        skip: false,
        result: None,
        error: None,
    }
}

fn check(condition: bool, detail: String) -> Result<(), String> {
    if condition {
        Ok(())
    } else {
        Err(detail)
    }
}
