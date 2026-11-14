module main

import praxo

fn main() {
	schema := praxo.parse_json('{"type":"object","required":["name"],"properties":{"name":{"type":"string"}}}') or {
		panic(err)
	}
	valid := praxo.parse_json('{"name":"ok"}') or { panic(err) }
	invalid := praxo.parse_json('{}') or { panic(err) }
	assert praxo.validate_schema(schema, valid).len == 0
	assert praxo.validate_schema(schema, invalid).len > 0
	println('V structured output example passed')
}
