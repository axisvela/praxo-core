module praxo

import regex
import x.json2

pub struct ValidationError {
pub:
	path    string
	message string
}

fn add_error(mut errors []ValidationError, path string, message string) {
	errors << ValidationError{path: path, message: message}
}

fn check_enum(schema json2.Any, data json2.Any, path string, mut errors []ValidationError) {
	values := get_array(schema, 'enum')
	if values.len == 0 {
		return
	}
	for value in values {
		if json_equals(value, data) {
			return
		}
	}
	add_error(mut errors, path, 'value not in enum')
}

fn visit_schema(schema json2.Any, data json2.Any, path string, mut errors []ValidationError) {
	if !is_object(schema) {
		return
	}
	kind := get_string(schema, 'type') or { '' }
	if is_null(data) {
		if kind != '' {
			add_error(mut errors, path, 'expected ${kind}, got null')
		}
		return
	}
	if kind == 'object' {
		if !is_object(data) {
			add_error(mut errors, path, 'expected object')
			return
		}
		object := as_object(data)
		for name in get_array(schema, 'required') {
			required := as_string(name) or { continue }
			if required !in object {
				add_error(mut errors, '${path}.${required}', 'required field missing')
			}
		}
		properties := get_object(schema, 'properties')
		for name, child in properties {
			if name in object {
				visit_schema(child, object[name] or { json2.null }, '${path}.${name}', mut errors)
			}
		}
		return
	}
	if kind == 'array' {
		if !is_array(data) {
			add_error(mut errors, path, 'expected array')
			return
		}
		items := get(schema, 'items') or { json2.null }
		legacy_items := as_array(items)
		for index, value in as_array(data) {
			if is_object(items) {
				visit_schema(items, value, '${path}[${index}]', mut errors)
			} else if legacy_items.len > 0 {
				visit_schema(legacy_items[0], value, '${path}[${index}]', mut errors)
			}
		}
		return
	}
	if kind == 'string' {
		value := as_string(data) or {
			add_error(mut errors, path, 'expected string')
			return
		}
		length := value.len_utf8()
		minimum := get_int(schema, 'minLength', 0)
		maximum := get_int(schema, 'maxLength', 0)
		if minimum > 0 && length < minimum {
			add_error(mut errors, path, 'min length ${minimum}, got ${length}')
		}
		if maximum > 0 && length > maximum {
			add_error(mut errors, path, 'max length ${maximum}, got ${length}')
		}
		if pattern := get_string(schema, 'pattern') {
			mut expression := regex.regex_opt(pattern) or {
				add_error(mut errors, path, "invalid pattern '${pattern}'")
				return
			}
			start, _ := expression.find(value)
			if start < 0 {
				add_error(mut errors, path, "pattern '${pattern}' not matched")
			}
		}
		check_enum(schema, data, path, mut errors)
		return
	}
	if kind == 'number' || kind == 'integer' {
		value := as_f64(data) or {
			add_error(mut errors, path, 'expected number')
			return
		}
		if kind == 'integer' && value != f64(int(value)) {
			add_error(mut errors, path, 'expected integer, got ${value}')
			return
		}
		check_enum(schema, data, path, mut errors)
		minimum := get(schema, 'minimum') or { json2.null }
		maximum := get(schema, 'maximum') or { json2.null }
		if min := as_f64(minimum) {
			if min != 0 && value < min {
				add_error(mut errors, path, 'value below minimum')
			}
		}
		if max := as_f64(maximum) {
			if max != 0 && value > max {
				add_error(mut errors, path, 'value above maximum')
			}
		}
		return
	}
	if kind == 'boolean' {
		if as_bool(data) == none {
			add_error(mut errors, path, 'expected boolean')
			return
		}
		check_enum(schema, data, path, mut errors)
	}
}

pub fn validate_schema(schema json2.Any, data json2.Any) []ValidationError {
	mut errors := []ValidationError{}
	visit_schema(schema, data, '$', mut errors)
	return errors
}
