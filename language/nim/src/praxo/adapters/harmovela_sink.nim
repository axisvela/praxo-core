import std/[httpclient, json, strformat, strutils, times]

import ../errors
import ../jsonutil
import ../models
import ../runtime

type
  HarmovelaResponse* = object
    status*: int
    body*: string

  HarmovelaTransport* = proc(path: string, body: string,
                             headers: seq[(string, string)]): HarmovelaResponse {.closure.}

  HarmovelaClock* = proc(): Time {.closure.}

  HarmovelaConfig = ref object
    baseUrl: string
    source: string
    specVersion: string
    transport: HarmovelaTransport
    clock: HarmovelaClock
    timeoutMs: int

proc rfc3339Nano(at: Time): string =
  let value = at.utc
  result = &"{value.year:04}-{ord(value.month):02}-{value.monthday:02}T" &
           &"{value.hour:02}:{value.minute:02}:{value.second:02}." &
           &"{value.nanosecond:09}Z"

proc eventId(prefix: string, at: Time): string =
  let value = if prefix.len > 0: prefix else: "event"
  value & "-" & $(at.toUnix * 1_000_000_000 + at.nanosecond.int64)

proc bounded(body: string): string =
  if body.len > 1024:
    return body[0 ..< 1024]
  return body

proc post(config: HarmovelaConfig, path: string, body: string,
          headers: seq[(string, string)]): HarmovelaResponse =
  let client = newHttpClient(timeout = config.timeoutMs)
  defer: client.close()
  var httpHeaders = newHttpHeaders()
  for (key, value) in headers:
    httpHeaders[key] = value
  client.headers = httpHeaders
  let response = client.request(config.baseUrl & path, httpMethod = HttpPost, body = body)
  result = HarmovelaResponse(status: response.code.int, body: response.body)

proc send(config: HarmovelaConfig, event: Event) =
  if config.baseUrl.len == 0:
    raisePraxo("HARMOVELA_URL", "harmovela: base URL is required")
  let at = if config.clock != nil: config.clock() else: getTime()
  var payload = newJObject()
  if not event.data.isNil and event.data.kind == JObject:
    for key, value in event.data:
      payload[key] = value
  if event.sessionId.len > 0:
    payload["session_id"] = %event.sessionId
  if event.runId.len > 0:
    payload["run_id"] = %event.runId
  let prefix = if event.runId.len > 0: event.runId
               elif event.sessionId.len > 0: event.sessionId
               else: "event"
  var envelope = newJObject()
  envelope["spec_version"] = %config.specVersion
  envelope["id"] = %eventId(prefix, at)
  envelope["type"] = %event.kind
  envelope["source"] = %config.source
  envelope["created_at"] = %rfc3339Nano(at)
  envelope["payload"] = payload
  let body = encodeJson(envelope)
  let headers = @[("content-type", "application/json")]
  let response = if config.transport != nil:
      config.transport("/events", body, headers)
    else:
      config.post("/events", body, headers)
  if response.status >= 200 and response.status < 300:
    return
  raisePraxo("HARMOVELA_HTTP",
    "harmovela: HTTP " & $response.status & ": " & bounded(response.body))

proc newHarmovelaSink*(baseUrl: string, source: string = "praxo-core",
                       specVersion: string = "0.2",
                       transport: HarmovelaTransport = nil,
                       clock: HarmovelaClock = nil,
                       timeoutMs: int = 10000): Sink =
  let config = HarmovelaConfig(
    baseUrl: baseUrl.strip(leading = false, chars = {'/'}),
    source: if source.len > 0: source else: "praxo-core",
    specVersion: if specVersion.len > 0: specVersion else: "0.2",
    transport: transport,
    clock: clock,
    timeoutMs: timeoutMs,
  )
  result = Sink()
  result.handler = proc(event: Event) =
    config.send(event)
