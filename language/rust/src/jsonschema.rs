use regex::Regex;
use serde_json::{Map, Value};

use crate::errors::{PraxoError, Result};

#[derive(Debug, Clone, PartialEq)]
pub struct ValidationError {
    pub path: String,
    pub message: String,
}

#[derive(Debug, Clone, PartialEq)]
pub struct Schema {
    value: Value,
}

impl Schema {
    pub fn from_json(raw: &str) -> Result<Self> {
        let value: Value = serde_json::from_str(raw)
            .map_err(|error| PraxoError::new("SCHEMA_INVALID", error.to_string()))?;
        if !value.is_object() {
            return Err(PraxoError::new(
                "SCHEMA_INVALID",
                "schema must be an object",
            ));
        }
        Ok(Self { value })
    }

    pub fn validate(&self, data: &Value) -> Vec<ValidationError> {
        validate(&self.value, data)
    }
}

pub fn validate(schema: &Value, data: &Value) -> Vec<ValidationError> {
    let mut errors = Vec::new();
    let empty = Map::new();
    visit(schema.as_object().unwrap_or(&empty), data, "$", &mut errors);
    errors
}

fn visit(schema: &Map<String, Value>, data: &Value, path: &str, errors: &mut Vec<ValidationError>) {
    let kind = schema.get("type").and_then(Value::as_str).unwrap_or("");
    if data.is_null() {
        if !kind.is_empty() {
            errors.push(ValidationError {
                path: path.to_string(),
                message: format!("expected {kind}, got null"),
            });
        }
        return;
    }
    match kind {
        "object" => visit_object(schema, data, path, errors),
        "array" => visit_array(schema, data, path, errors),
        "string" => visit_string(schema, data, path, errors),
        "number" | "integer" => visit_number(schema, kind, data, path, errors),
        "boolean" => visit_boolean(schema, data, path, errors),
        _ => {}
    }
}

fn visit_object(
    schema: &Map<String, Value>,
    data: &Value,
    path: &str,
    errors: &mut Vec<ValidationError>,
) {
    let Some(object) = data.as_object() else {
        errors.push(ValidationError {
            path: path.to_string(),
            message: "expected object".to_string(),
        });
        return;
    };
    if let Some(required) = schema.get("required").and_then(Value::as_array) {
        for name in required.iter().filter_map(Value::as_str) {
            if !object.contains_key(name) {
                errors.push(ValidationError {
                    path: format!("{path}.{name}"),
                    message: "required field missing".to_string(),
                });
            }
        }
    }
    if let Some(properties) = schema.get("properties").and_then(Value::as_object) {
        for (key, child) in properties {
            if let Some(value) = object.get(key) {
                let empty = Map::new();
                visit(
                    child.as_object().unwrap_or(&empty),
                    value,
                    &format!("{path}.{key}"),
                    errors,
                );
            }
        }
    }
}

fn visit_array(
    schema: &Map<String, Value>,
    data: &Value,
    path: &str,
    errors: &mut Vec<ValidationError>,
) {
    let Some(array) = data.as_array() else {
        errors.push(ValidationError {
            path: path.to_string(),
            message: "expected array".to_string(),
        });
        return;
    };
    if let Some(items) = schema.get("items").and_then(Value::as_object) {
        for (index, item) in array.iter().enumerate() {
            visit(items, item, &format!("{path}[{index}]"), errors);
        }
    }
}

fn visit_string(
    schema: &Map<String, Value>,
    data: &Value,
    path: &str,
    errors: &mut Vec<ValidationError>,
) {
    let Some(text) = data.as_str() else {
        errors.push(ValidationError {
            path: path.to_string(),
            message: "expected string".to_string(),
        });
        return;
    };
    let length = text.chars().count();
    let min = schema.get("minLength").and_then(Value::as_u64).unwrap_or(0) as usize;
    let max = schema.get("maxLength").and_then(Value::as_u64).unwrap_or(0) as usize;
    if min > 0 && length < min {
        errors.push(ValidationError {
            path: path.to_string(),
            message: format!("min length {min}, got {length}"),
        });
    }
    if max > 0 && length > max {
        errors.push(ValidationError {
            path: path.to_string(),
            message: format!("max length {max}, got {length}"),
        });
    }
    if let Some(pattern) = schema.get("pattern").and_then(Value::as_str) {
        match Regex::new(pattern) {
            Ok(regex) => {
                if !regex.is_match(text) {
                    errors.push(ValidationError {
                        path: path.to_string(),
                        message: format!("pattern '{pattern}' not matched"),
                    });
                }
            }
            Err(error) => errors.push(ValidationError {
                path: path.to_string(),
                message: format!("invalid pattern '{pattern}': {error}"),
            }),
        }
    }
    check_enum(schema, data, path, errors);
}

fn visit_number(
    schema: &Map<String, Value>,
    kind: &str,
    data: &Value,
    path: &str,
    errors: &mut Vec<ValidationError>,
) {
    let Some(number) = data.as_f64() else {
        errors.push(ValidationError {
            path: path.to_string(),
            message: "expected number".to_string(),
        });
        return;
    };
    if kind == "integer" && number.fract() != 0.0 {
        errors.push(ValidationError {
            path: path.to_string(),
            message: format!("expected integer, got {number}"),
        });
        return;
    }
    check_enum(schema, data, path, errors);
    let minimum = schema.get("minimum").and_then(Value::as_f64).unwrap_or(0.0);
    let maximum = schema.get("maximum").and_then(Value::as_f64).unwrap_or(0.0);
    if minimum != 0.0 && number < minimum {
        errors.push(ValidationError {
            path: path.to_string(),
            message: format!("value {number} below minimum {minimum}"),
        });
    }
    if maximum != 0.0 && number > maximum {
        errors.push(ValidationError {
            path: path.to_string(),
            message: format!("value {number} above maximum {maximum}"),
        });
    }
}

fn visit_boolean(
    schema: &Map<String, Value>,
    data: &Value,
    path: &str,
    errors: &mut Vec<ValidationError>,
) {
    if !data.is_boolean() {
        errors.push(ValidationError {
            path: path.to_string(),
            message: "expected boolean".to_string(),
        });
        return;
    }
    check_enum(schema, data, path, errors);
}

fn check_enum(
    schema: &Map<String, Value>,
    data: &Value,
    path: &str,
    errors: &mut Vec<ValidationError>,
) {
    let Some(values) = schema.get("enum").and_then(Value::as_array) else {
        return;
    };
    if !values.is_empty() && !values.contains(data) {
        errors.push(ValidationError {
            path: path.to_string(),
            message: format!("value not in enum: {values:?}"),
        });
    }
}
