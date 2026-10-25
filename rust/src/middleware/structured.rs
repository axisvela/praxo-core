use serde_json::{Map, Value};

use crate::agent::RunResult;
use crate::errors::{PraxoError, Result};
use crate::jsonschema::validate;
use crate::middleware::{Middleware, ModelCall};
use crate::model::{ResponseFormat, ToolSpec};

pub const STRATEGY_AUTO: &str = "auto";
pub const STRATEGY_PROVIDER: &str = "provider";
pub const STRATEGY_TOOL: &str = "tool";

type Validator = Box<dyn Fn(&str) -> Result<()> + Send + Sync>;
type Repairer = Box<dyn Fn(&str, &PraxoError) -> Result<String> + Send + Sync>;

pub struct StructuredOutput {
    pub schema: Map<String, Value>,
    pub name: String,
    pub strategy: String,
    pub max_repairs: usize,
    validator: Option<Validator>,
    repairer: Option<Repairer>,
}

impl StructuredOutput {
    pub fn new(schema: Map<String, Value>) -> Self {
        Self {
            schema,
            name: String::new(),
            strategy: STRATEGY_AUTO.to_string(),
            max_repairs: 0,
            validator: None,
            repairer: None,
        }
    }

    pub fn with_name(mut self, name: impl Into<String>) -> Self {
        self.name = name.into();
        self
    }

    pub fn with_strategy(mut self, strategy: impl Into<String>) -> Self {
        self.strategy = strategy.into();
        self
    }

    pub fn with_repairs(mut self, max_repairs: usize) -> Self {
        self.max_repairs = max_repairs;
        self
    }

    pub fn with_validator(
        mut self,
        validator: impl Fn(&str) -> Result<()> + Send + Sync + 'static,
    ) -> Self {
        self.validator = Some(Box::new(validator));
        self
    }

    pub fn with_repairer(
        mut self,
        repairer: impl Fn(&str, &PraxoError) -> Result<String> + Send + Sync + 'static,
    ) -> Self {
        self.repairer = Some(Box::new(repairer));
        self
    }

    pub fn output_name(&self) -> String {
        if self.name.trim().is_empty() {
            "structured_output".to_string()
        } else {
            self.name.trim().to_string()
        }
    }

    pub fn response_format(&self) -> Option<ResponseFormat> {
        if self.strategy == STRATEGY_TOOL || self.schema.is_empty() {
            return None;
        }
        Some(ResponseFormat {
            name: Some(self.output_name()),
            schema: Some(self.schema.clone()),
        })
    }

    pub fn tool_spec(&self) -> ToolSpec {
        ToolSpec {
            name: self.output_name(),
            description: "Return the final answer as structured JSON matching the response schema."
                .to_string(),
            parameters: Some(self.schema.clone()),
            risk: Some("low".to_string()),
        }
    }

    pub fn apply(&self, result: &mut RunResult) -> Result<()> {
        let mut output = result.output.clone();
        let mut last_error = None;
        for attempt in 0..=self.max_repairs {
            match self.run_validation(&output) {
                Ok(()) => {
                    result.output = output;
                    return Ok(());
                }
                Err(error) => last_error = Some(error),
            }
            if attempt == self.max_repairs {
                break;
            }
            let Some(repairer) = &self.repairer else {
                break;
            };
            let repaired = repairer(&output, last_error.as_ref().expect("validation error"))?;
            if repaired.trim().is_empty() {
                return Err(PraxoError::structured_output(
                    "agent: structured output validation failed: repair returned empty output",
                ));
            }
            output = repaired;
        }
        Err(PraxoError::structured_output(format!(
            "agent: structured output validation failed: {}",
            last_error.map(|error| error.message).unwrap_or_default()
        )))
    }

    pub fn validate_arguments(&self, arguments: &Map<String, Value>) -> Result<()> {
        if let Some(validator) = &self.validator {
            return validator(&serde_json::to_string(arguments).unwrap_or_default());
        }
        let errors = validate(&Value::Object(self.schema.clone()), &Value::Object(arguments.clone()));
        if errors.is_empty() {
            Ok(())
        } else {
            Err(PraxoError::structured_output(format!("schema: {errors:?}")))
        }
    }

    fn run_validation(&self, output: &str) -> Result<()> {
        if let Some(validator) = &self.validator {
            return validator(output);
        }
        let data = extract_json(output)?;
        let errors = validate(&Value::Object(self.schema.clone()), &data);
        if errors.is_empty() {
            Ok(())
        } else {
            Err(PraxoError::structured_output(format!("schema: {errors:?}")))
        }
    }
}

impl Middleware for StructuredOutput {
    fn name(&self) -> &str {
        "structured-output"
    }

    fn before_model(&self, call: &mut ModelCall) -> Result<()> {
        if call.request.response_format.is_none() {
            call.request.response_format = self.response_format();
        }
        if self.strategy == STRATEGY_TOOL
            && call
                .request
                .tools
                .iter()
                .any(|spec| spec.name == self.output_name())
        {
            call.request.tool_choice = Some("required".to_string());
        }
        Ok(())
    }

    fn after_run(
        &self,
        result: Option<&mut RunResult>,
        error: Option<&PraxoError>,
    ) -> Result<()> {
        if error.is_some() {
            return Ok(());
        }
        if let Some(result) = result {
            self.apply(result)?;
        }
        Ok(())
    }
}

pub fn extract_json(output: &str) -> Result<Value> {
    let mut text = output.trim();
    if text.is_empty() {
        return Err(PraxoError::structured_output("empty output"));
    }
    if text.starts_with("```") {
        if let Some(newline) = text.find('\n') {
            text = &text[newline + 1..];
        }
        text = text.trim_end_matches("```").trim();
    }
    let start = text
        .find(|ch| ch == '{' || ch == '[')
        .ok_or_else(|| PraxoError::structured_output("output does not contain JSON"))?;
    serde_json::from_str(&text[start..])
        .map_err(|error| PraxoError::structured_output(format!("decode JSON: {error}")))
}


