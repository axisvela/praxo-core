use std::path::PathBuf;
use std::time::Duration;

use praxo_core::plugin_process::{ProcessConfig, ProcessHost};

fn fixture() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("tests")
        .join("fixtures")
        .join("process_plugin.py")
}

fn config() -> ProcessConfig {
    let mut config = ProcessConfig::new("com.example.echo", python());
    config.args = vec![fixture().to_string_lossy().to_string()];
    config.invoke_timeout = Duration::from_secs(2);
    config.grace_period = Duration::from_secs(2);
    config
}

fn python() -> String {
    std::env::var("PYTHON").unwrap_or_else(|_| "python".to_string())
}

#[test]
fn process_host_round_trip() {
    let mut host = ProcessHost::new(config()).unwrap();
    host.start().unwrap();
    assert!(host.is_active());
    let result = host
        .invoke("tool.provider", "echo", br#"{"text":"hi"}"#)
        .unwrap();
    assert_eq!(result, br#"{"text":"hi"}"#);
    host.stop();
    assert!(!host.is_active());
}

#[test]
fn process_host_maps_errors() {
    let mut host = ProcessHost::new(config()).unwrap();
    host.start().unwrap();
    let denied = host.invoke("tool.provider", "denied", &[]).unwrap_err();
    assert_eq!(denied.code, "CAPABILITY_DENIED");
    let missing = host.invoke("tool.provider", "missing", &[]).unwrap_err();
    assert_eq!(missing.code, "NOT_FOUND");
    host.stop();
}

#[test]
fn process_host_rejects_before_start() {
    let mut host = ProcessHost::new(config()).unwrap();
    let error = host.invoke("tool.provider", "echo", &[]).unwrap_err();
    assert_eq!(error.code, "NOT_ACTIVE");
}

#[test]
fn process_host_times_out() {
    let mut config = config();
    config.invoke_timeout = Duration::from_millis(200);
    let mut host = ProcessHost::new(config).unwrap();
    host.start().unwrap();
    let error = host.invoke("tool.provider", "block", &[]).unwrap_err();
    assert_eq!(error.code, "TIMEOUT");
}
