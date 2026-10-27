module praxo

import x.json2

pub fn parse_json(text string) !json2.Any {
	return json2.decode[json2.Any](text)!
}

pub fn encode_json(value json2.Any) string {
	return json2.encode[json2.Any](value)
}

pub fn is_null(value json2.Any) bool {
	return value is json2.Null
}

pub fn is_object(value json2.Any) bool {
	return value is map[string]json2.Any
}

pub fn is_array(value json2.Any) bool {
	return value is []json2.Any
}

pub fn as_object(value json2.Any) map[string]json2.Any {
	if value is map[string]json2.Any {
		return value
	}
	return map[string]json2.Any{}
}

pub fn as_array(value json2.Any) []json2.Any {
	if value is []json2.Any {
		return value
	}
	return []json2.Any{}
}

pub fn as_string(value json2.Any) ?string {
	if value is string {
		return value as string
	}
	return none
}

pub fn as_bool(value json2.Any) ?bool {
	if value is bool {
		return value as bool
	}
	return none
}

pub fn as_f64(value json2.Any) ?f64 {
	match value {
		f64 { return value }
		f32 { return f64(value) }
		i64 { return f64(value) }
		int { return f64(value) }
		i32 { return f64(value) }
		i16 { return f64(value) }
		i8 { return f64(value) }
		u64 { return f64(value) }
		u32 { return f64(value) }
		u16 { return f64(value) }
		u8 { return f64(value) }
		else { return none }
	}
}

pub fn as_int(value json2.Any) ?int {
	number := as_f64(value) or { return none }
	if number != f64(int(number)) {
		return none
	}
	return int(number)
}

pub fn get(value json2.Any, key string) ?json2.Any {
	if value is map[string]json2.Any {
		return value[key] or { return none }
	}
	return none
}

pub fn get_or(value json2.Any, key string, fallback json2.Any) json2.Any {
	return get(value, key) or { fallback }
}

pub fn get_string(value json2.Any, key string) ?string {
	item := get(value, key) or { return none }
	return as_string(item)
}

pub fn get_bool(value json2.Any, key string, fallback bool) bool {
	item := get(value, key) or { return fallback }
	return as_bool(item) or { fallback }
}

pub fn get_int(value json2.Any, key string, fallback int) int {
	item := get(value, key) or { return fallback }
	return as_int(item) or { fallback }
}

pub fn get_array(value json2.Any, key string) []json2.Any {
	item := get(value, key) or { return []json2.Any{} }
	return as_array(item)
}

pub fn get_object(value json2.Any, key string) map[string]json2.Any {
	item := get(value, key) or { return map[string]json2.Any{} }
	return as_object(item)
}

pub fn json_equals(left json2.Any, right json2.Any) bool {
	if is_null(left) || is_null(right) {
		return is_null(left) && is_null(right)
	}
	if left is map[string]json2.Any {
		if right is map[string]json2.Any {
			if left.len != right.len {
				return false
			}
			for key, item in left {
				other := right[key] or { return false }
				if !json_equals(item, other) {
					return false
				}
			}
			return true
		}
		return false
	}
	if left is []json2.Any {
		if right is []json2.Any {
			if left.len != right.len {
				return false
			}
			for index, item in left {
				if !json_equals(item, right[index]) {
					return false
				}
			}
			return true
		}
		return false
	}
	if l := as_f64(left) {
		if r := as_f64(right) {
			return l == r
		}
		return false
	}
	if l := as_string(left) {
		if r := as_string(right) {
			return l == r
		}
		return false
	}
	if l := as_bool(left) {
		if r := as_bool(right) {
			return l == r
		}
		return false
	}
	return false
}

pub fn json_from_ints(values []int) json2.Any {
	mut items := []json2.Any{cap: values.len}
	for value in values {
		items << json2.Any(f64(value))
	}
	return json2.Any(items)
}

pub fn json_from_strings(values []string) json2.Any {
	mut items := []json2.Any{cap: values.len}
	for value in values {
		items << json2.Any(value)
	}
	return json2.Any(items)
}
