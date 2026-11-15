module main

import os
import praxo
import time
import x.json2

fn env_or(name string, fallback string) string {
	value := os.getenv(name)
	if value == '' {
		return fallback
	}
	return value
}

fn get_time_value(arguments map[string]json2.Any) json2.Any {
	mut zone := 'utc'
	if value := arguments['zone'] {
		if value is string {
			zone = value
		}
	}
	stamp := if zone == 'local' {
		time.now().format_rfc3339()
	} else {
		time.now().utc().format_rfc3339()
	}
	return json2.Any(stamp)
}

fn main() {
	base_url := env_or('PRAXO_BASE_URL', 'http://localhost:11434/v1')
	model_name := env_or('PRAXO_MODEL', 'qwen3.5:4b')
	api_key := env_or('PRAXO_API_KEY', '')
	prompt := env_or('PRAXO_PROMPT',
		'What time is it? Use get_time with zone set to utc and reply with the time.')

	adapter := praxo.openai_compatible_with_options(base_url, model_name, praxo.OpenAIOptions{
		api_key: api_key
	})

	tool := praxo.func_tool('get_time',
		'Return the current time. The zone argument accepts utc or local.')
	tool.invoke = get_time_value

	mut options := praxo.agent_options(praxo.openai_compatible_model(adapter))
	options.tools = [tool]
	options.system_prompt = 'You are a concise assistant. Use the provided tools when they help.'
	options.max_steps = 4
	options.allowed_tools = ['get_time']
	options.policy = fn (kind string) bool {
		return kind == 'model.generate' || kind == 'tool.invoke'
	}

	result := praxo.run_agent(options, praxo.session('live-model', []praxo.Message{}), prompt) or {
		eprintln('live model run failed: ${err.msg()}')
		eprintln('Check PRAXO_BASE_URL (${base_url}), PRAXO_MODEL (${model_name}), and PRAXO_API_KEY')
		exit(1)
	}
	println(result.output)
}
