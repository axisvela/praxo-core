module main

import praxo

fn main() {
	mut allow := praxo.checkpoint_allowlist()
	allow.register('order') or { panic(err) }
	value := praxo.parse_json('{"value":"x"}') or { panic(err) }
	data := allow.marshal('order', value) or { panic(err) }
	decoded := allow.unmarshal(data) or { panic(err) }
	assert praxo.json_equals(decoded, value)
	println('V checkpoint example passed')
}
