use std::sync::{Arc, Mutex};

use praxo_core::errors::Result;
use praxo_core::event::Event;
use praxo_core::harmovela::{HttpRequest, HttpResponse, Transport};
use praxo_core::otel::Sink;
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
    data.insert("secret".to_string(), json!("hidden"));
    let mut event = Event::new("tool.call", "s1").run("run-123").data(data);
    event.at = Some("2026-11-10T07:00:00Z".to_string());
    event
}

fn span(body: &str) -> Value {
    let payload: Value = serde_json::from_str(body).expect("payload");
    payload["resourceSpans"][0]["scopeSpans"][0]["spans"][0].clone()
}

#[test]
fn posts_otlp_span_with_allowed_attributes() {
    let capture = Arc::new(Capture::new(200, ""));
    let mut sink = Sink::with_transport("http://otel.test/v1/traces", capture.clone());
    sink.service_name = "praxo-test".to_string();
    sink.allowed_data_keys = vec!["name".to_string()];
    sink.emit(&event()).expect("emit");

    let requests = capture.requests.lock().expect("requests");
    assert_eq!(requests.len(), 1);
    let request = &requests[0];
    assert_eq!(request.method, "POST");
    assert_eq!(request.url, "http://otel.test/v1/traces");
    assert!(request
        .headers
        .iter()
        .any(|(name, value)| name == "content-type" && value == "application/json"));

    let payload: Value = serde_json::from_str(&request.body).expect("payload");
    assert_eq!(
        payload["resourceSpans"][0]["resource"]["attributes"][0]["value"]
            ["stringValue"],
        json!("praxo-test")
    );
    let span = span(&request.body);
    assert_eq!(span["name"], json!("praxo.tool.call"));
    assert_eq!(span["traceId"].as_str().unwrap().len(), 32);
    assert_eq!(span["spanId"].as_str().unwrap().len(), 16);
    assert_eq!(span["startTimeUnixNano"], span["endTimeUnixNano"]);

    let attributes = span["attributes"].as_array().expect("attributes");
    let find = |key: &str| {
        attributes
            .iter()
            .find(|item| item["key"] == json!(key))
            .map(|item| item["value"]["stringValue"].clone())
    };
    assert_eq!(find("praxo.event.type"), Some(json!("tool.call")));
    assert_eq!(find("praxo.session.id"), Some(json!("s1")));
    assert_eq!(find("praxo.run.id"), Some(json!("run-123")));
    assert_eq!(find("praxo.event.data.name"), Some(json!("echo")));
    assert_eq!(find("praxo.event.data.secret"), None);
}

#[test]
fn identifiers_are_deterministic() {
    let capture = Arc::new(Capture::new(200, ""));
    let sink = Sink::with_transport("http://otel.test/v1/traces", capture.clone());
    sink.emit(&event()).expect("emit");
    sink.emit(&event()).expect("emit");
    let requests = capture.requests.lock().expect("requests");
    let first = span(&requests[0].body);
    let second = span(&requests[1].body);
    assert_eq!(first["traceId"], second["traceId"]);
    assert_eq!(first["spanId"], second["spanId"]);
}

#[test]
fn rejects_non_2xx_response() {
    let capture = Arc::new(Capture::new(503, "down"));
    let sink = Sink::with_transport("http://otel.test/v1/traces", capture);
    let error = sink.emit(&event()).expect_err("expected error");
    assert!(error.to_string().contains("503"));
}
