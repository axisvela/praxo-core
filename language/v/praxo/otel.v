module praxo

import net.http
import time
import x.json2

pub struct OtelResponse {
pub:
	status int
	body   string
}

pub type OtelTransport = fn (endpoint string, body string, headers map[string]string) !OtelResponse

pub type OtelClock = fn () i64

pub fn otel_default_clock() i64 {
	return time.now().unix_nano()
}

pub fn otel_default_transport(endpoint string, body string, headers map[string]string) !OtelResponse {
	if endpoint == '' {
		return praxo_error('OTEL_URL', 'otel: endpoint is required')
	}
	header := http.new_header(key: .content_type, value: headers['content-type'])
	response := http.fetch(
		url: endpoint
		method: .post
		data: body
		header: header
	) or {
		return praxo_error('OTEL_HTTP', 'otel request failed: ${err.msg()}')
	}
	return OtelResponse{status: response.status_code, body: response.body}
}

pub struct OtelOptions {
pub:
	service_name      string        = 'praxo-core'
	allowed_data_keys []string
	transport         OtelTransport = otel_default_transport
	clock             OtelClock     = otel_default_clock
}

@[heap]
pub struct OtelSink {
pub mut:
	endpoint          string
	service_name      string        = 'praxo-core'
	allowed_data_keys []string
	transport         OtelTransport = otel_default_transport
	clock             OtelClock     = otel_default_clock
}

pub fn new_otel_sink(endpoint string, options OtelOptions) &OtelSink {
	return &OtelSink{
		endpoint: endpoint.trim_space()
		service_name: if options.service_name != '' { options.service_name } else { 'praxo-core' }
		allowed_data_keys: options.allowed_data_keys
		transport: options.transport
		clock: options.clock
	}
}

pub fn otel_sink(endpoint string, options OtelOptions) &Sink {
	adapter := new_otel_sink(endpoint, options)
	return &Sink{
		handler: fn [adapter] (event Event) ! {
			adapter.emit(event)!
		}
	}
}

pub fn (sink &OtelSink) emit(event Event) ! {
	if sink.endpoint == '' {
		return praxo_error('OTEL_URL', 'otel: endpoint is required')
	}
	stamp := sink.clock()
	payload := otel_payload(sink, event, stamp)
	body := encode_json(json2.Any(payload))
	mut headers := map[string]string{}
	headers['content-type'] = 'application/json'
	response := sink.transport(sink.endpoint, body, headers)!
	if response.status >= 200 && response.status < 300 {
		return
	}
	detail := if response.body.len > 512 { response.body[..512] } else { response.body }
	return praxo_error('OTEL_HTTP', 'otel: HTTP ${response.status}: ${detail}')
}

fn otel_attribute(key string, value string) json2.Any {
	mut wrapped := map[string]json2.Any{}
	wrapped['stringValue'] = json2.Any(value)
	mut attribute := map[string]json2.Any{}
	attribute['key'] = json2.Any(key)
	attribute['value'] = json2.Any(wrapped)
	return json2.Any(attribute)
}

fn otel_data_text(value json2.Any) string {
	if text := as_string(value) {
		return text
	}
	return encode_json(value)
}

fn otel_hash32(text string, seed u32) u32 {
	mut low := u32(1) + seed
	mut high := seed
	for byte in text.bytes() {
		low = (low + u32(byte)) % u32(65521)
		high = (high + low) % u32(65521)
	}
	return (high << 16) | low
}

fn otel_hex32(value u32) string {
	digits := '0123456789abcdef'
	mut output := []u8{len: 8}
	mut number := value
	for index := 7; index >= 0; index-- {
		output[index] = digits[int(number & u32(0xF))]
		number = number >> 4
	}
	return output.bytestr()
}

fn otel_stable_id(text string) string {
	return otel_hex32(otel_hash32(text, u32(1))) + otel_hex32(otel_hash32(text, u32(2)))
}

fn otel_payload(sink &OtelSink, event Event, stamp i64) map[string]json2.Any {
	stamp_text := stamp.str()
	data_text := if is_null(event.data) { '' } else { encode_json(event.data) }
	key := '${event.session_id}|${event.run_id}|${event.kind}|${stamp_text}|${data_text}'
	trace_id := otel_stable_id('trace-a:${key}') + otel_stable_id('trace-b:${key}')
	span_id := otel_stable_id('span:${key}')
	mut attributes := []json2.Any{}
	attributes << otel_attribute('praxo.event.type', event.kind)
	if event.session_id != '' {
		attributes << otel_attribute('praxo.session.id', event.session_id)
	}
	if event.run_id != '' {
		attributes << otel_attribute('praxo.run.id', event.run_id)
	}
	attributes << otel_attribute('praxo.event.at', stamp_text)
	data := as_object(event.data)
	for name in sink.allowed_data_keys {
		if name in data {
			value := data[name] or { json2.null }
			attributes << otel_attribute('praxo.event.data.${name}', otel_data_text(value))
		}
	}
	mut span := map[string]json2.Any{}
	span['traceId'] = json2.Any(trace_id)
	span['spanId'] = json2.Any(span_id)
	span['name'] = json2.Any('praxo.${event.kind}')
	span['kind'] = json2.Any(f64(1))
	span['startTimeUnixNano'] = json2.Any(stamp_text)
	span['endTimeUnixNano'] = json2.Any(stamp_text)
	span['attributes'] = json2.Any(attributes)
	mut spans := []json2.Any{}
	spans << json2.Any(span)
	mut scope := map[string]json2.Any{}
	scope['name'] = json2.Any('praxo-core')
	scope['spans'] = json2.Any(spans)
	mut scope_spans := []json2.Any{}
	scope_spans << json2.Any(scope)
	mut resource_attributes := []json2.Any{}
	service_name := if sink.service_name != '' { sink.service_name } else { 'praxo-core' }
	resource_attributes << otel_attribute('service.name', service_name)
	mut resource := map[string]json2.Any{}
	resource['attributes'] = json2.Any(resource_attributes)
	mut resource_span := map[string]json2.Any{}
	resource_span['resource'] = json2.Any(resource)
	resource_span['scopeSpans'] = json2.Any(scope_spans)
	mut resource_spans := []json2.Any{}
	resource_spans << json2.Any(resource_span)
	mut envelope := map[string]json2.Any{}
	envelope['resourceSpans'] = json2.Any(resource_spans)
	return envelope
}
