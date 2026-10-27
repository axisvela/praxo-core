module praxo

import x.json2

pub struct Manifest {
pub:
	schema_version int
	id             string
	version        string
	kind           string
	entrypoint     map[string]json2.Any
	protocol       string
	capabilities   []string
	permissions    map[string]json2.Any
	limits         map[string]json2.Any
	isolation      string
	health         map[string]json2.Any
}

const known_kinds = [
	'tool.provider.v1',
	'model.provider.v1',
	'policy.provider.v1',
	'memory.provider.v1',
	'sandbox.provider.v1',
]

const manifest_keys = [
	'schemaVersion',
	'id',
	'version',
	'kind',
	'entrypoint',
	'protocol',
	'capabilities',
	'permissions',
	'limits',
	'isolation',
	'health',
	'signature',
	'sbom',
]

const entrypoint_keys = ['type', 'command', 'module', 'image', 'args', 'dir']
const permission_keys = ['filesystem', 'network', 'env']
const limit_keys = ['memoryMB', 'cpuMillis', 'timeoutMs', 'maxInflight']
const health_keys = ['method', 'intervalMs']
const signature_keys = ['algorithm', 'keyId']

fn check_keys(value map[string]json2.Any, allowed []string, where string) !void {
	for key in value.keys() {
		if key !in allowed {
			return error('plugin: manifest: unknown field ${key} in ${where}')
		}
	}
}

fn object_field(value json2.Any, where string) !map[string]json2.Any {
	if is_null(value) {
		return map[string]json2.Any{}
	}
	if value is map[string]json2.Any {
		return value
	}
	return error('plugin: manifest: ${where} must be an object')
}

fn string_field(value json2.Any, where string) !string {
	if value is string {
		return value as string
	}
	return error('plugin: manifest: ${where} must be a string')
}

fn integer_field(value json2.Any, where string) !int {
	number := as_f64(value) or {
		return error('plugin: manifest: ${where} must be an integer')
	}
	if number != f64(int(number)) {
		return error('plugin: manifest: ${where} must be an integer')
	}
	return int(number)
}

fn text_present(value json2.Any) bool {
	if value is string {
		return (value as string) != ''
	}
	return false
}

fn valid_reverse_dns(id string) bool {
	parts := id.split('.')
	if parts.len < 2 {
		return false
	}
	for part in parts {
		if part == '' || part.len > 63 {
			return false
		}
		first := part[0]
		last := part[part.len - 1]
		if !is_lower_alnum(first) || !is_lower_alnum(last) {
			return false
		}
		for index := 0; index < part.len; index++ {
			character := part[index]
			if !is_lower_alnum(character) && character != `-` {
				return false
			}
		}
	}
	return true
}

fn is_lower_alnum(character u8) bool {
	return (character >= `a` && character <= `z`) || (character >= `0` && character <= `9`)
}

fn valid_semver(version string) bool {
	mut core := version
	if dash := core.index('-') {
		core = core.substr(0, dash)
	}
	if plus := core.index('+') {
		core = core.substr(0, plus)
	}
	parts := core.split('.')
	if parts.len != 3 {
		return false
	}
	for part in parts {
		if part == '' {
			return false
		}
		if part.len > 1 && part.starts_with('0') {
			return false
		}
		for index := 0; index < part.len; index++ {
			if part[index] < `0` || part[index] > `9` {
				return false
			}
		}
	}
	return true
}

pub fn parse_manifest(raw string) !Manifest {
	if raw.trim_space() == '' {
		return error('plugin: manifest is empty')
	}
	value := parse_json(raw) or { return error('plugin: manifest: ${err}') }
	if !is_object(value) {
		return error('plugin: manifest must be an object')
	}
	root := as_object(value)
	check_keys(root, manifest_keys, 'manifest')!
	schema_version := integer_field(root['schemaVersion'] or {
		return error('plugin: manifest: schemaVersion is required')
	}, 'schemaVersion')!
	if schema_version != 1 {
		return error('plugin: manifest: schemaVersion = ${schema_version}, want 1')
	}
	id := string_field(root['id'] or {
		return error('plugin: manifest: id is required')
	}, 'id')!
	if !valid_reverse_dns(id) {
		return error('plugin: manifest: id ${id} is not reverse-DNS')
	}
	version := string_field(root['version'] or {
		return error('plugin: manifest: version is required')
	}, 'version')!
	if !valid_semver(version) {
		return error('plugin: manifest: version ${version} is not semver')
	}
	kind := string_field(root['kind'] or {
		return error('plugin: manifest: kind is required')
	}, 'kind')!
	if kind !in known_kinds {
		return error('plugin: manifest: kind ${kind} is not a known contract')
	}
	protocol := string_field(root['protocol'] or {
		return error('plugin: manifest: protocol is required')
	}, 'protocol')!
	if protocol != 'jsonrpc-2' {
		return error('plugin: manifest: protocol = ${protocol}, want jsonrpc-2')
	}
	entrypoint := object_field(root['entrypoint'] or {
		return error('plugin: manifest: entrypoint is required')
	}, 'entrypoint')!
	check_keys(entrypoint, entrypoint_keys, 'entrypoint')!
	entry_type := string_field(entrypoint['type'] or {
		return error('plugin: manifest: entrypoint.type is required')
	}, 'entrypoint.type')!
	required_field := match entry_type {
		'process' { 'command' }
		'wasm' { 'module' }
		'container' { 'image' }
		else { return error('plugin: manifest: unknown entrypoint type ${entry_type}') }
	}
	if !text_present(entrypoint[required_field] or { json2.null }) {
		return error('plugin: manifest: ${entry_type} entrypoint requires ${required_field}')
	}
	isolation := string_field(root['isolation'] or {
		return error('plugin: manifest: isolation is required')
	}, 'isolation')!
	if isolation != entry_type {
		return error('plugin: manifest: isolation ${isolation} does not match entrypoint ${entry_type}')
	}
	permissions := object_field(root['permissions'] or { json2.null }, 'permissions')!
	check_keys(permissions, permission_keys, 'permissions')!
	limits := object_field(root['limits'] or { json2.null }, 'limits')!
	check_keys(limits, limit_keys, 'limits')!
	for key, item in limits {
		if integer_field(item, 'limits.${key}')! < 0 {
			return error('plugin: manifest: limits must not be negative')
		}
	}
	health := object_field(root['health'] or { json2.null }, 'health')!
	check_keys(health, health_keys, 'health')!
	if signature_value := root['signature'] {
		if !is_null(signature_value) {
			signature := object_field(signature_value, 'signature')!
			check_keys(signature, signature_keys, 'signature')!
			if !text_present(signature['algorithm'] or { json2.null })
				|| !text_present(signature['keyId'] or { json2.null }) {
				return error('plugin: manifest: signature requires algorithm and keyId')
			}
		}
	}
	mut capabilities := []string{}
	if capability_value := root['capabilities'] {
		if !is_null(capability_value) {
			if !is_array(capability_value) {
				return error('plugin: manifest: capabilities must be an array')
			}
			mut seen := map[string]bool{}
			for item in as_array(capability_value) {
				capability := string_field(item, 'capabilities')!
				if capability == '' {
					return error('plugin: manifest: capability must not be empty')
				}
				if capability in seen {
					return error('plugin: manifest: duplicate capability')
				}
				seen[capability] = true
				capabilities << capability
			}
		}
	}
	return Manifest{
		schema_version: schema_version
		id: id
		version: version
		kind: kind
		entrypoint: entrypoint
		protocol: protocol
		capabilities: capabilities
		permissions: permissions
		limits: limits
		isolation: isolation
		health: health
	}
}
