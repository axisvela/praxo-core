module praxo

import net.http
import x.json2

pub type ProviderTransport = fn (base_url string, path string, payload map[string]json2.Any, headers map[string]string) !map[string]json2.Any

fn provider_default_transport(base_url string, path string, payload map[string]json2.Any, headers map[string]string) !map[string]json2.Any {
	if base_url == '' {
		return praxo_error('PROVIDER_HTTP', 'provider base URL is required')
	}
	mut request_headers := http.new_header(key: .content_type, value: 'application/json')
	request_headers.add_custom_map(headers)!
	response := http.fetch(
		url: base_url + path
		method: .post
		data: encode_json(json2.Any(payload))
		header: request_headers
	) or {
		return praxo_error('PROVIDER_HTTP', 'provider request failed: ${err.msg()}')
	}
	if response.status_code < 200 || response.status_code >= 300 {
		detail := if response.body.len > 512 { response.body[..512] } else { response.body }
		return praxo_error('PROVIDER_HTTP', 'provider returned HTTP ${response.status_code}: ${detail}')
	}
	data := parse_json(response.body) or {
		return praxo_error('PROVIDER_JSON', 'provider returned invalid JSON')
	}
	return as_object(data)
}
