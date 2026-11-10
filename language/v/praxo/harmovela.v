module praxo

import net.http
import time
import x.json2

pub struct HarmovelaResponse {
pub:
	status int
	body   string
}

pub type HarmovelaTransport = fn (base_url string, path string, body string, headers map[string]string) !HarmovelaResponse

pub type HarmovelaClock = fn () i64

pub fn harmovela_default_clock() i64 {
	return time.now().unix_nano()
}

pub fn harmovela_default_transport(base_url string, path string, body string, headers map[string]string) !HarmovelaResponse {
	if base_url == '' {
		return praxo_error('HARMOVELA_URL', 'harmovela: base URL is required')
	}
	mut header := http.new_header(key: .content_type, value: headers['content-type'])
	response := http.fetch(
		url: base_url + path
		method: .post
		data: body
		header: header
	) or {
		return praxo_error('HARMOVELA_HTTP', 'harmovela request failed: ${err.msg()}')
	}
	return HarmovelaResponse{status: response.status_code, body: response.body}
}

pub struct HarmovelaOptions {
pub:
	source       string             = 'praxo-core'
	spec_version string             = '0.2'
	transport    HarmovelaTransport = harmovela_default_transport
	clock        HarmovelaClock     = harmovela_default_clock
}

@[heap]
pub struct HarmovelaSink {
pub mut:
	base_url     string
	source       string             = 'praxo-core'
	spec_version string             = '0.2'
	transport    HarmovelaTransport = harmovela_default_transport
	clock        HarmovelaClock     = harmovela_default_clock
}

pub fn new_harmovela_sink(base_url string, options HarmovelaOptions) &HarmovelaSink {
	return &HarmovelaSink{
		base_url: base_url.trim_right('/')
		source: if options.source != '' { options.source } else { 'praxo-core' }
		spec_version: if options.spec_version != '' { options.spec_version } else { '0.2' }
		transport: options.transport
		clock: options.clock
	}
}

pub fn harmovela_sink(base_url string, options HarmovelaOptions) &Sink {
	adapter := new_harmovela_sink(base_url, options)
	return &Sink{
		handler: fn [adapter] (event Event) !void {
			adapter.emit(event)!
		}
	}
}

pub fn (sink &HarmovelaSink) emit(event Event) !void {
	if sink.base_url == '' {
		return praxo_error('HARMOVELA_URL', 'harmovela: base URL is required')
	}
	stamp := sink.clock()
	seconds := stamp / 1_000_000_000
	nanos := int(stamp % 1_000_000_000)
	payload := harmovela_payload(event)
	mut envelope := map[string]json2.Any{}
	envelope['spec_version'] = json2.Any(sink.spec_version)
	envelope['id'] = json2.Any(harmovela_event_id(event, stamp))
	envelope['type'] = json2.Any(event.kind)
	envelope['source'] = json2.Any(sink.source)
	envelope['created_at'] = json2.Any(harmovela_timestamp(seconds, nanos))
	envelope['payload'] = json2.Any(payload)
	body := encode_json(json2.Any(envelope))
	mut headers := map[string]string{}
	headers['content-type'] = 'application/json'
	response := sink.transport(sink.base_url, '/events', body, headers)!
	if response.status >= 200 && response.status < 300 {
		return
	}
	detail := if response.body.len > 1024 { response.body[..1024] } else { response.body }
	return praxo_error('HARMOVELA_HTTP', 'harmovela: HTTP ${response.status}: ${detail}')
}

fn harmovela_payload(event Event) map[string]json2.Any {
	mut payload := map[string]json2.Any{}
	for key, value in as_object(event.data) {
		payload[key] = value
	}
	if event.session_id != '' {
		payload['session_id'] = json2.Any(event.session_id)
	}
	if event.run_id != '' {
		payload['run_id'] = json2.Any(event.run_id)
	}
	return payload
}

fn harmovela_event_id(event Event, stamp i64) string {
	prefix := if event.run_id != '' {
		event.run_id
	} else if event.session_id != '' {
		event.session_id
	} else {
		'event'
	}
	return '${prefix}-${stamp}'
}

fn harmovela_floor_div(a i64, b i64) i64 {
	q := a / b
	r := a % b
	if r != 0 && ((r < 0 && b > 0) || (r > 0 && b < 0)) {
		return q - 1
	}
	return q
}

fn harmovela_pad(value int, width int) string {
	mut text := value.str()
	for text.len < width {
		text = '0' + text
	}
	return text
}

fn harmovela_timestamp(seconds i64, nanos int) string {
	days := harmovela_floor_div(seconds, 86400)
	remainder := seconds - days * 86400
	hour := int(remainder / 3600)
	minute := int(remainder % 3600) / 60
	second := int(remainder % 60)
	z := days + 719468
	era := harmovela_floor_div(z, 146097)
	doe := z - era * 146097
	yoe := (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
	year := yoe + era * 400
	doy := doe - (365 * yoe + yoe / 4 - yoe / 100)
	mp := (5 * doy + 2) / 153
	day := int(doy - (153 * mp + 2) / 5 + 1)
	mut month := int(mp + 3)
	mut calendar_year := int(year)
	if mp >= 10 {
		month = int(mp - 9)
	}
	if month <= 2 {
		calendar_year += 1
	}
	year_text := harmovela_pad(calendar_year, 4)
	month_text := harmovela_pad(month, 2)
	day_text := harmovela_pad(day, 2)
	hour_text := harmovela_pad(hour, 2)
	minute_text := harmovela_pad(minute, 2)
	second_text := harmovela_pad(second, 2)
	nanos_text := harmovela_pad(nanos, 9)
	return '${year_text}-${month_text}-${day_text}T${hour_text}:${minute_text}:${second_text}.${nanos_text}Z'
}
