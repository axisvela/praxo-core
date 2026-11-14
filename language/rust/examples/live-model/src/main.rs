use std::sync::Arc;
use std::time::{SystemTime, UNIX_EPOCH};

use serde_json::{Map, Value};

use praxo_core::agent::{Agent, AgentOptions, Session};
use praxo_core::errors::Result;
use praxo_core::openai_compat::{OpenAICompatConfig, OpenAICompatible};
use praxo_core::policy::{Action, Decision, Hook};
use praxo_core::tool::{Registry, Tool};

struct TimeTool;

impl Tool for TimeTool {
    fn name(&self) -> &str {
        "get_time"
    }

    fn description(&self) -> &str {
        "Return the current Unix time in seconds."
    }

    fn invoke(&self, _args: &Map<String, Value>) -> Result<Value> {
        let seconds = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs();
        Ok(Value::String(seconds.to_string()))
    }
}

struct AllowGetTime;

impl Hook for AllowGetTime {
    fn authorize(&self, action: &Action) -> Result<Decision> {
        match action.kind.as_str() {
            "model.generate" => Ok(Decision::allow("model generation")),
            "tool.invoke" => {
                if action.tool_name.as_deref() == Some("get_time") {
                    Ok(Decision::allow("get_time is permitted"))
                } else {
                    Ok(Decision::deny("only get_time is permitted"))
                }
            }
            _ => Ok(Decision::deny("unsupported action")),
        }
    }
}

fn env_or(name: &str, fallback: &str) -> String {
    std::env::var(name).unwrap_or_else(|_| fallback.to_string())
}

fn main() -> Result<()> {
    let base_url = env_or("PRAXO_BASE_URL", "http://localhost:11434/v1");
    let model_name = env_or("PRAXO_MODEL", "qwen3.5:4b");
    let prompt = env_or(
        "PRAXO_PROMPT",
        "What time is it? Use the get_time tool and reply with the time.",
    );

    let model = Arc::new(OpenAICompatible::with_ureq(OpenAICompatConfig {
        base_url: base_url.clone(),
        api_key: std::env::var("PRAXO_API_KEY").unwrap_or_default(),
        model: model_name.clone(),
        timeout_secs: 120,
    }));

    let mut tools = Registry::new();
    tools.register(Arc::new(TimeTool) as Arc<dyn Tool>);

    let mut options = AgentOptions::new(model);
    options.tools = Some(Arc::new(tools));
    options.system_prompt =
        "You are a concise assistant. Use the provided tools when they help.".to_string();
    options.max_steps = 4;
    options.allowed_tools = vec!["get_time".to_string()];
    options.policy = Some(Arc::new(AllowGetTime));

    let agent = Agent::new(options)?;
    let result = agent
        .run(&Session::new("live-model"), &prompt)
        .map_err(|error| {
            eprintln!(
                "live model run failed: {error}\n\nCheck PRAXO_BASE_URL ({base_url}), PRAXO_MODEL ({model_name}), and PRAXO_API_KEY"
            );
            error
        })?;

    println!("{}", result.output);
    Ok(())
}
