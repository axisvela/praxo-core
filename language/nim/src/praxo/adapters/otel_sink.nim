import std/[httpclient, json, strutils, times]

import ../errors
import ../jsonutil
import ../models
import ../runtime

type
  OtelResponse* = object
    status*: int
    body*: string

  OtelTransport* = proc(endpoint: string, body: string,
                        headers: seq[(string, string)]): OtelResponse {.closure.}

  OtelClock* = proc(): Time {.closure.}

  OtelConfig = ref object
    endpoint: string
    serviceName: string
    allowedDataKeys: seq[string]
    transport: OtelTransport
    clock: OtelClock
    timeoutMs: int

const
  maxBody = 512

proc bounded(body: string): string =
  if body.len > maxBody:
    return body[0 ..< maxBody]
  return body

proc unixNanos(at: Time): int64 =
  return at.toUnix * 1_000_000_000 + at.nanosecond.int64

proc stableId(text: string): string =
  var hash = 0xcbf29ce484222325'u64
  for byte in text:
    hash = hash xor uint64(ord(byte))
    hash = hash * 0x100000001b3'u64
  return toHex(hash, 16).toLowerAscii()

proc attribute(key: string, value: string): JsonNode =
  result = newJObject()
  result["key"] = %key
  var wrapped = newJObject()
  wrapped["stringValue"] = %value
  result["value"] = wrapped

proc textValue(value: JsonNode): string =
  if value.isNil:
    return ""
  if value.kind == JString:
    return value.getStr()
  return encodeJson(value)

proc payload(config: OtelConfig, event: Event, nanos: int64): JsonNode =
  let stamp = $nanos
  let dataText = if event.data.isNil: "" else: encodeJson(event.data)
  let key = event.sessionId & "|" & event.runId & "|" & event.kind & "|" &
            stamp & "|" & dataText
  let traceId = stableId("trace-a:" & key) & stableId("trace-b:" & key)
  let spanId = stableId("span:" & key)
  var attributes = newJArray()
  attributes.add(attribute("praxo.event.type", event.kind))
  if event.sessionId.len > 0:
    attributes.add(attribute("praxo.session.id", event.sessionId))
  if event.runId.len > 0:
    attributes.add(attribute("praxo.run.id", event.runId))
  attributes.add(attribute("praxo.event.at", stamp))
  if not event.data.isNil and event.data.kind == JObject:
    for name in config.allowedDataKeys:
      if event.data.hasKey(name):
        attributes.add(attribute("praxo.event.data." & name,
                                 textValue(event.data[name])))
  var span = newJObject()
  span["traceId"] = %traceId
  span["spanId"] = %spanId
  span["name"] = %("praxo." & event.kind)
  span["kind"] = %1
  span["startTimeUnixNano"] = %stamp
  span["endTimeUnixNano"] = %stamp
  span["attributes"] = attributes
  var spans = newJArray()
  spans.add(span)
  var scope = newJObject()
  scope["name"] = %"praxo-core"
  scope["spans"] = spans
  var scopeSpans = newJArray()
  scopeSpans.add(scope)
  var resourceAttributes = newJArray()
  resourceAttributes.add(attribute("service.name", config.serviceName))
  var resource = newJObject()
  resource["attributes"] = resourceAttributes
  var resourceSpan = newJObject()
  resourceSpan["resource"] = resource
  resourceSpan["scopeSpans"] = scopeSpans
  var resourceSpans = newJArray()
  resourceSpans.add(resourceSpan)
  result = newJObject()
  result["resourceSpans"] = resourceSpans

proc post(config: OtelConfig, body: string,
          headers: seq[(string, string)]): OtelResponse =
  let client = newHttpClient(timeout = config.timeoutMs)
  defer: client.close()
  var httpHeaders = newHttpHeaders()
  for (key, value) in headers:
    httpHeaders[key] = value
  client.headers = httpHeaders
  let response = client.request(config.endpoint, httpMethod = HttpPost, body = body)
  result = OtelResponse(status: response.code.int, body: response.body)

proc send(config: OtelConfig, event: Event) =
  if config.endpoint.len == 0:
    raisePraxo("OTEL_URL", "otel: endpoint is required")
  let at = if config.clock != nil: config.clock() else: getTime()
  let body = encodeJson(payload(config, event, unixNanos(at)))
  let headers = @[("content-type", "application/json")]
  let response = if config.transport != nil:
      config.transport(config.endpoint, body, headers)
    else:
      config.post(body, headers)
  if response.status >= 200 and response.status < 300:
    return
  raisePraxo("OTEL_HTTP",
    "otel: HTTP " & $response.status & ": " & bounded(response.body))

proc newOtelSink*(endpoint: string, serviceName: string = "praxo-core",
                  allowedDataKeys: seq[string] = @[],
                  transport: OtelTransport = nil,
                  clock: OtelClock = nil,
                  timeoutMs: int = 10000): Sink =
  let config = OtelConfig(
    endpoint: endpoint.strip(),
    serviceName: if serviceName.len > 0: serviceName else: "praxo-core",
    allowedDataKeys: allowedDataKeys,
    transport: transport,
    clock: clock,
    timeoutMs: timeoutMs,
  )
  result = Sink()
  result.handler = proc(event: Event) =
    config.send(event)
