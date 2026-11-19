module praxo

import encoding.base64
import os
import time
import x.json2

pub const plugin_process_protocol_version = 1
pub const plugin_process_control_service = 'host.control'
pub const plugin_process_default_token_env = 'PRAXOVELA_PLUGIN_TOKEN'

pub struct PluginProcessConfig {
pub mut:
	plugin_id      string
	path           string
	args           []string
	env            map[string]string
	token          string
	token_env_var  string = plugin_process_default_token_env
	start_timeout  time.Duration = 10 * time.second
	invoke_timeout time.Duration = 30 * time.second
	grace_period   time.Duration = 5 * time.second
}

pub struct PluginProcessError {
pub:
	code    string
	message string
}

pub fn (error PluginProcessError) code() int {
	return 0
}

pub fn (error PluginProcessError) msg() string {
	return '${error.code}: ${error.message}'
}

@[heap]
pub struct PluginProcessHost {
pub mut:
	config   PluginProcessConfig
	token    string
	process  &os.Process = unsafe { nil }
	sequence int
	active   bool
	buffer   string
}

pub fn start_plugin_process(config PluginProcessConfig) !&PluginProcessHost {
	if config.plugin_id == '' {
		return error('INVALID_REQUEST: plugin: PluginID is required')
	}
	if config.path == '' {
		return error('INVALID_REQUEST: plugin: path is required')
	}
	mut process := os.new_process(config.path)
	process.set_args(config.args)
	process.set_redirect_stdio()
	mut env := os.environ()
	if config.env.len > 0 {
		env = config.env.clone()
	}
	token_env := if config.token_env_var != '' {
		config.token_env_var
	} else {
		plugin_process_default_token_env
	}
	token := if config.token != '' { config.token } else { random_token() }
	env[token_env] = token
	process.set_environment(env)
	process.run()
	mut host := &PluginProcessHost{
		config: config
		token: token
		process: process
	}
	_ := host.call(plugin_process_control_service, 'health', '', config.start_timeout) or {
		process.signal_kill()
		return error(err.msg())
	}
	host.active = true
	return host
}

pub fn (mut host PluginProcessHost) invoke(service string, method string, payload []u8) ![]u8 {
	if !host.active {
		return PluginProcessError{ code: 'NOT_ACTIVE', message: 'plugin: host is not active' }
	}
	return host.call(service, method, base64.encode(payload), host.config.invoke_timeout)
}

pub fn (mut host PluginProcessHost) stop() {
	if host.process == unsafe { nil } {
		return
	}
	if host.active {
		_ := host.call(plugin_process_control_service, 'shutdown', '', host.config.grace_period) or { []u8{} } 
	}
	host.active = false
	host.process.signal_kill()
	host.process.close()
	host.process = unsafe { nil }
}

fn (mut host PluginProcessHost) call(service string, method string, payload string, timeout time.Duration) ![]u8 {
	host.sequence++
	id := 'req-${host.sequence}'
	mut frame := map[string]json2.Any{}
	frame['id'] = json2.Any(id)
	frame['version'] = json2.Any(plugin_process_protocol_version)
	frame['plugin_id'] = json2.Any(host.config.plugin_id)
	frame['service'] = json2.Any(service)
	frame['method'] = json2.Any(method)
	frame['token'] = json2.Any(host.token)
	frame['payload'] = json2.Any(payload)
	host.process.stdin_write(encode_json(json2.Any(frame)) + '\n')
	deadline := time.now().add(timeout)
	for {
		if time.now() > deadline {
			host.cancel(id)
			host.process.signal_kill()
			return PluginProcessError{ code: 'TIMEOUT', message: 'plugin: invocation timed out' }
		}
		if host.process.is_pending(.stdout) {
			host.buffer += host.process.stdout_read()
			for {
				index := host.buffer.index('\n') or { -1 }
				if index < 0 {
					break
				}
				line := host.buffer[..index].trim_space()
				host.buffer = host.buffer[index + 1..]
				if line == '' {
					continue
				}
				decoded := parse_json(line) or { continue }
				if decoded !is map[string]json2.Any {
					continue
				}
				response := decoded as map[string]json2.Any
				if get_string(response, 'id') or { '' } != id {
					continue
				}
				if !get_bool(response, 'ok', false) {
					code := get_string(response, 'code') or { 'INTERNAL' }
					message := get_string(response, 'message') or { '' }
					return PluginProcessError{ code: normalize_code(code), message: message }
				}
				text := get_string(response, 'payload') or { '' }
				return base64.decode(text)
			}
		}
		time.sleep(2 * time.millisecond)
	}
	return error('INTERNAL: unreachable')
}

fn (mut host PluginProcessHost) cancel(id string) {
	mut frame := map[string]json2.Any{}
	frame['id'] = json2.Any(id)
	frame['version'] = json2.Any(plugin_process_protocol_version)
	frame['plugin_id'] = json2.Any(host.config.plugin_id)
	frame['service'] = json2.Any(plugin_process_control_service)
	frame['method'] = json2.Any('cancel')
	frame['token'] = json2.Any(host.token)
	host.process.stdin_write(encode_json(json2.Any(frame)) + '\n')
}

fn normalize_code(code string) string {
	return if code in ['CAPABILITY_DENIED', 'NOT_ACTIVE', 'NOT_FOUND', 'INVALID_REQUEST', 'TIMEOUT', 'INTERNAL', 'CANCELED'] {
		code
	} else {
		'INTERNAL'
	}
}

fn random_token() string {
	mut out := ''
	for _ in 0 .. 64 {
		out += '0123456789abcdef'[rand_u8() % 16].ascii_str()
	}
	return out
}

fn rand_u8() u8 {
	return u8((time.now().unix_nano() >> 8) & 0xff)
}
