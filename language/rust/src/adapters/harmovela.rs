use std::io::{Read, Write};
use std::net::TcpStream;
use std::sync::Arc;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use serde::Serialize;
use serde_json::{Map, Value};

use crate::errors::{PraxoError, Result};
use crate::event::Event;

#[derive(Debug, Clone)]
pub struct HttpRequest {
    pub method: String,
    pub url: String,
    pub headers: Vec<(String, String)>,
    pub body: String,
}

#[derive(Debug, Clone)]
pub struct HttpResponse {
    pub status: u16,
    pub body: String,
}

pub trait Transport: Send + Sync {
    fn send(&self, request: &HttpRequest) -> Result<HttpResponse>;
}

pub struct Sink {
    pub base_url: String,
    pub source: String,
    pub spec_version: String,
    transport: Arc<dyn Transport>,
}

impl Sink {
    pub fn new(base_url: impl Into<String>) -> Self {
        Self::with_transport(base_url, Arc::new(StdTransport))
    }

    pub fn with_transport(
        base_url: impl Into<String>,
        transport: Arc<dyn Transport>,
    ) -> Self {
        Self {
            base_url: base_url.into(),
            source: "praxo-core".to_string(),
            spec_version: "0.2".to_string(),
            transport,
        }
    }

    pub fn emit(&self, event: &Event) -> Result<()> {
        if self.base_url.is_empty() {
            return Err(PraxoError::new(
                "HARMOVELA_BASE_URL",
                "harmovela: base URL is required",
            ));
        }
        let source = if self.source.is_empty() {
            "praxo-core"
        } else {
            &self.source
        };
        let spec_version = if self.spec_version.is_empty() {
            "0.2"
        } else {
            &self.spec_version
        };
        let (seconds, nanos) = event_parts(event);
        let mut payload = event.data.clone().unwrap_or_default();
        if !event.session_id.is_empty() {
            payload.insert(
                "session_id".to_string(),
                Value::String(event.session_id.clone()),
            );
        }
        if let Some(run_id) = &event.run_id {
            if !run_id.is_empty() {
                payload.insert("run_id".to_string(), Value::String(run_id.clone()));
            }
        }
        let envelope = Envelope {
            spec_version,
            id: event_id(event, seconds, nanos),
            kind: &event.kind,
            source,
            created_at: format_rfc3339(seconds, nanos),
            payload,
        };
        let body = serde_json::to_string(&envelope)
            .map_err(|error| PraxoError::new("HARMOVELA_JSON", error.to_string()))?;
        let request = HttpRequest {
            method: "POST".to_string(),
            url: format!("{}/events", self.base_url.trim_end_matches('/')),
            headers: vec![("content-type".to_string(), "application/json".to_string())],
            body,
        };
        let response = self.transport.send(&request)?;
        if !(200..300).contains(&response.status) {
            let bounded: String = response.body.chars().take(512).collect();
            return Err(PraxoError::new(
                "HARMOVELA_HTTP",
                format!(
                    "harmovela: HTTP {}: {}",
                    response.status,
                    bounded.trim()
                ),
            ));
        }
        Ok(())
    }
}

impl crate::event::Sink for Sink {
    fn emit(&self, event: &Event) -> Result<()> {
        Sink::emit(self, event)
    }
}

#[derive(Serialize)]
struct Envelope<'a> {
    spec_version: &'a str,
    id: String,
    #[serde(rename = "type")]
    kind: &'a str,
    source: &'a str,
    created_at: String,
    payload: Map<String, Value>,
}

pub struct StdTransport;

impl Transport for StdTransport {
    fn send(&self, request: &HttpRequest) -> Result<HttpResponse> {
        let rest = request.url.strip_prefix("http://").ok_or_else(|| {
            PraxoError::new(
                "HARMOVELA_TRANSPORT",
                "harmovela: default transport supports http only; inject a Transport for https",
            )
        })?;
        let (authority, path) = match rest.find('/') {
            Some(index) => (&rest[..index], &rest[index..]),
            None => (rest, "/"),
        };
        let (host, port) = split_authority(authority)?;
        let mut stream = TcpStream::connect((host.as_str(), port)).map_err(|error| {
            PraxoError::new("HARMOVELA_TRANSPORT", error.to_string())
        })?;
        stream
            .set_read_timeout(Some(Duration::from_secs(30)))
            .map_err(|error| PraxoError::new("HARMOVELA_TRANSPORT", error.to_string()))?;
        stream
            .set_write_timeout(Some(Duration::from_secs(30)))
            .map_err(|error| PraxoError::new("HARMOVELA_TRANSPORT", error.to_string()))?;
        let mut raw = format!(
            "{} {} HTTP/1.1\r\nHost: {}\r\nConnection: close\r\n",
            request.method, path, authority
        );
        for (name, value) in &request.headers {
            raw.push_str(&format!("{}: {}\r\n", name, value));
        }
        raw.push_str(&format!("Content-Length: {}\r\n\r\n", request.body.len()));
        raw.push_str(&request.body);
        stream
            .write_all(raw.as_bytes())
            .map_err(|error| PraxoError::new("HARMOVELA_TRANSPORT", error.to_string()))?;
        let mut bytes = Vec::new();
        stream
            .read_to_end(&mut bytes)
            .map_err(|error| PraxoError::new("HARMOVELA_TRANSPORT", error.to_string()))?;
        parse_response(&bytes)
    }
}

fn split_authority(authority: &str) -> Result<(String, u16)> {
    match authority.rsplit_once(':') {
        Some((host, port)) if !host.is_empty() => {
            let port = port.parse::<u16>().map_err(|_| {
                PraxoError::new("HARMOVELA_TRANSPORT", "harmovela: invalid port")
            })?;
            Ok((host.to_string(), port))
        }
        Some(_) => Err(PraxoError::new(
            "HARMOVELA_TRANSPORT",
            "harmovela: invalid host",
        )),
        None if !authority.is_empty() => Ok((authority.to_string(), 80)),
        None => Err(PraxoError::new(
            "HARMOVELA_TRANSPORT",
            "harmovela: invalid host",
        )),
    }
}

fn parse_response(bytes: &[u8]) -> Result<HttpResponse> {
    let split = bytes
        .windows(4)
        .position(|window| window == b"\r\n\r\n")
        .ok_or_else(|| {
            PraxoError::new("HARMOVELA_TRANSPORT", "harmovela: invalid HTTP response")
        })?;
    let head = String::from_utf8_lossy(&bytes[..split]);
    let status = head
        .lines()
        .next()
        .and_then(|line| line.split_whitespace().nth(1))
        .and_then(|code| code.parse::<u16>().ok())
        .ok_or_else(|| {
            PraxoError::new("HARMOVELA_TRANSPORT", "harmovela: invalid HTTP status")
        })?;
    let body = String::from_utf8_lossy(&bytes[split + 4..]).to_string();
    Ok(HttpResponse { status, body })
}

fn event_parts(event: &Event) -> (i64, u32) {
    if let Some(raw) = &event.at {
        if let Some(parts) = parse_rfc3339(raw) {
            return parts;
        }
    }
    let elapsed = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap_or_default();
    (elapsed.as_secs() as i64, elapsed.subsec_nanos())
}

fn event_id(event: &Event, seconds: i64, nanos: u32) -> String {
    let prefix = event
        .run_id
        .as_deref()
        .filter(|value| !value.is_empty())
        .or_else(|| {
            if event.session_id.is_empty() {
                None
            } else {
                Some(event.session_id.as_str())
            }
        })
        .unwrap_or("event");
    format!("{}-{}", prefix, seconds * 1_000_000_000 + nanos as i64)
}

fn parse_rfc3339(raw: &str) -> Option<(i64, u32)> {
    let bytes = raw.as_bytes();
    if bytes.len() < 20
        || bytes[4] != b'-'
        || bytes[7] != b'-'
        || bytes[10] != b'T'
        || bytes[13] != b':'
        || bytes[16] != b':'
    {
        return None;
    }
    let year = raw[0..4].parse::<i64>().ok()?;
    let month = raw[5..7].parse::<u32>().ok()?;
    let day = raw[8..10].parse::<u32>().ok()?;
    let hour = raw[11..13].parse::<u32>().ok()?;
    let minute = raw[14..16].parse::<u32>().ok()?;
    let second = raw[17..19].parse::<u32>().ok()?;
    if !(1..=12).contains(&month) || !(1..=31).contains(&day) {
        return None;
    }
    let mut index = 19;
    let mut nanos = 0u32;
    if bytes.get(index) == Some(&b'.') {
        index += 1;
        let start = index;
        while index < bytes.len() && bytes[index].is_ascii_digit() {
            index += 1;
        }
        let digits = &raw[start..index];
        if digits.is_empty() || digits.len() > 9 {
            return None;
        }
        nanos = digits.parse::<u32>().ok()?;
        for _ in digits.len()..9 {
            nanos *= 10;
        }
    }
    if !matches!(bytes.get(index), Some(b'Z') | Some(b'z')) {
        return None;
    }
    let days = days_from_civil(year, month, day);
    let seconds = days * 86_400 + hour as i64 * 3_600 + minute as i64 * 60 + second as i64;
    Some((seconds, nanos))
}

fn format_rfc3339(seconds: i64, nanos: u32) -> String {
    let days = seconds.div_euclid(86_400);
    let day_seconds = seconds.rem_euclid(86_400);
    let (year, month, day) = civil_from_days(days);
    let hour = day_seconds / 3_600;
    let minute = (day_seconds % 3_600) / 60;
    let second = day_seconds % 60;
    format!(
        "{:04}-{:02}-{:02}T{:02}:{:02}:{:02}.{:09}Z",
        year, month, day, hour, minute, second, nanos
    )
}

fn days_from_civil(year: i64, month: u32, day: u32) -> i64 {
    let year = if month <= 2 { year - 1 } else { year };
    let era = if year >= 0 { year } else { year - 399 } / 400;
    let yoe = year - era * 400;
    let mp = if month > 2 { month - 3 } else { month + 9 } as i64;
    let doy = (153 * mp + 2) / 5 + day as i64 - 1;
    let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    era * 146_097 + doe - 719_468
}

fn civil_from_days(days: i64) -> (i64, u32, u32) {
    let z = days + 719_468;
    let era = if z >= 0 { z } else { z - 146_096 } / 146_097;
    let doe = z - era * 146_097;
    let yoe = (doe - doe / 1_460 + doe / 36_524 - doe / 146_096) / 365;
    let year = yoe + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let day = doy - (153 * mp + 2) / 5 + 1;
    let month = if mp < 10 { mp + 3 } else { mp - 9 };
    (
        if month <= 2 { year + 1 } else { year },
        month as u32,
        day as u32,
    )
}
