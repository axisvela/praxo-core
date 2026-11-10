use std::sync::{Arc, Mutex};

use praxo_core::errors::Result;
use praxo_core::event::Event;
use praxo_core::harmovela::{HttpRequest, HttpResponse, Sink, Transport};
use serde_json::{json, Map, Value};

struct Capture {
    status: u16,
    body: String,
    requests: Mutex<Vec<HttpRequest>>,
}

impl Capture {
    fn new(status: u16, body: &str) -> Self {
        Self {
            status,
            body: body.to_string(),
            requests: Mutex::new(Vec::new()),
        }
    }
}

impl Transport for Capture {
    fn send(&self, request: &HttpRequest) -> Result<HttpResponse> {
        self.requests
            .lock()
            .expect("requests")
            .push(request.clone());
        Ok(HttpResponse {
            status: self.status,
            body: self.body.clone(),
        })
    }
}

fn event() -> Event {
    let mut data = Map::new();
    data.insert("name".to_string(), json!("echo"));
    let mut event = Event::new("tool.call", "s1").run("run-123").data(data);
    event.at = Some("2026-11-10T07:00:00.000000000Z".to_string());
    event
}

#[test]
fn posts_envelope_and_merges_payload() {
    let capture = Arc::new(Capture::new(201, ""));
    let sink = Sink::with_transport(
        "http://harmovela.test/aep/api/",
        capture.clone(),
    );
    sink.emit(&event()).expect("emit");
    let requests = capture.requests.lock().expect("requests");
    assert_eq!(requests.len(), 1);
    let request = &requests[0];
    assert_eq!(request.method, "POST");
    assert_eq!(request.url, "http://harmovela.test/aep/api/events");
    assert!(request
        .headers
        .iter()
        .any(|(name, value)| name == "content-type" && value == "application/json"));
    let envelope: Value = serde_json::from_str(&request.body).expect("json");
    assert_eq!(envelope["spec_version"], "0.2");
    assert_eq!(envelope["id"], "run-123-1794294000000000000");
    assert_eq!(envelope["type"], "tool.call");
    assert_eq!(envelope["source"], "praxo-core");
    assert_eq!(envelope["created_at"], "2026-11-10T07:00:00.000000000Z");
    assert_eq!(
        envelope["payload"],
        json!({"name": "echo", "session_id": "s1", "run_id": "run-123"})
    );
}

#[test]
fn payload_merge_keeps_event_data_and_overrides_session() {
    let capture = Arc::new(Capture::new(201, ""));
    let mut sink = Sink::with_transport("http://harmovela.test", capture.clone());
    sink.source = "custom".to_string();
    sink.spec_version = "0.3".to_string();
    let mut data = Map::new();
    data.insert("name".to_string(), json!("echo"));
    data.insert("session_id".to_string(), json!("event-side"));
    data.insert("run_id".to_string(), json!("old"));
    let mut event = Event::new("tool.call", "s1").data(data);
    event.run_id = None;
    event.at = Some("2026-11-10T07:00:00.000000000Z".to_string());
    sink.emit(&event).expect("emit");
    let requests = capture.requests.lock().expect("requests");
    let envelope: Value = serde_json::from_str(&requests[0].body).expect("json");
    assert_eq!(envelope["source"], "custom");
    assert_eq!(envelope["spec_version"], "0.3");
    assert!(envelope["id"].as_str().unwrap().starts_with("s1-"));
    assert_eq!(
        envelope["payload"],
        json!({"name": "echo", "session_id": "s1", "run_id": "old"})
    );
}

#[test]
fn accepts_2xx_statuses() {
    for status in [200, 201, 204, 299] {
        let capture = Arc::new(Capture::new(status, ""));
        let sink = Sink::with_transport("http://harmovela.test", capture);
        sink.emit(&event()).expect("2xx status");
    }
}

#[test]
fn reports_status_and_bounded_body_on_non_2xx() {
    let capture = Arc::new(Capture::new(503, &"service down ".repeat(100)));
    let sink = Sink::with_transport("http://harmovela.test", capture);
    let error = sink.emit(&event()).expect_err("non-2xx");
    let message = error.to_string();
    assert!(message.contains("503"));
    assert!(message.contains("service down"));
    assert!(message.len() <= 600);
}
