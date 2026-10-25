pub const STREAM_VALUES: &str = "values";
pub const STREAM_UPDATES: &str = "updates";
pub const STREAM_MESSAGES: &str = "messages";
pub const STREAM_TASKS: &str = "tasks";
pub const STREAM_DEBUG: &str = "debug";
pub const STREAM_CHECKPOINT: &str = "checkpoint";

pub const STREAM_KINDS: [&str; 6] = [
    STREAM_VALUES,
    STREAM_UPDATES,
    STREAM_MESSAGES,
    STREAM_TASKS,
    STREAM_DEBUG,
    STREAM_CHECKPOINT,
];

#[derive(Debug, Clone)]
pub struct StreamPart {
    pub run_id: String,
    pub session_id: String,
    pub kind: String,
    pub step: usize,
    pub data: Option<serde_json::Value>,
    pub at: Option<String>,
}
