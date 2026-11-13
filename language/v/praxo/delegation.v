module praxo

import time

pub struct SubagentRequest {
pub mut:
	parent_session_id string
	agent_id          string
	prompt            string
	mode              string
}

pub struct SubagentResult {
pub:
	task_id  string
	agent_id string
	output   string
}

pub struct SubagentTask {
pub mut:
	id                string
	parent_session_id string
	agent_id          string
	mode              string
	status            string
	output            string
	error             string
	created_at        string
	updated_at        string
}

pub type SubagentRunner = fn (request SubagentRequest) !SubagentResult

pub type SubagentClock = fn () i64

fn missing_subagent_runner(_request SubagentRequest) !SubagentResult {
	return praxo_error('SUBAGENT_INVALID', 'agent: subagent runner is required')
}

pub fn subagent_default_clock() i64 {
	return time.now().unix_nano()
}

pub fn subagent_request(parent_session_id string, agent_id string, prompt string) SubagentRequest {
	return SubagentRequest{
		parent_session_id: parent_session_id
		agent_id: agent_id
		prompt: prompt
		mode: 'isolated'
	}
}

pub fn subagent_request_mode(parent_session_id string, agent_id string, prompt string, mode string) SubagentRequest {
	return SubagentRequest{
		parent_session_id: parent_session_id
		agent_id: agent_id
		prompt: prompt
		mode: if mode != '' { mode } else { 'isolated' }
	}
}

pub fn subagent_result(task_id string, agent_id string, output string) SubagentResult {
	return SubagentResult{task_id: task_id, agent_id: agent_id, output: output}
}

@[heap]
pub struct SubagentManager {
pub mut:
	runner     SubagentRunner = missing_subagent_runner
	clock      SubagentClock  = subagent_default_clock
	configured bool
}

pub fn subagent_manager(runner SubagentRunner) &SubagentManager {
	return &SubagentManager{runner: runner, configured: true}
}

pub fn subagent_run(runner SubagentRunner, request SubagentRequest) !SubagentTask {
	manager := subagent_manager(runner)
	return manager.run(request)
}

fn subagent_timestamp(stamp i64) string {
	seconds := stamp / 1_000_000_000
	nanos := int(stamp % 1_000_000_000)
	return harmovela_timestamp(seconds, nanos)
}

fn subagent_error_code(value IError) string {
	message := value.msg()
	if message.contains('|') {
		return message.split('|')[0]
	}
	return 'SUBAGENT_ERROR'
}

pub fn (manager &SubagentManager) run(request SubagentRequest) !SubagentTask {
	if !manager.configured {
		return praxo_error('SUBAGENT_INVALID', 'agent: subagent runner is required')
	}
	if request.parent_session_id == '' || request.agent_id == '' {
		return praxo_error('SUBAGENT_INVALID',
			'agent: subagent parent session and agent id are required')
	}
	stamp := manager.clock()
	mut task := SubagentTask{
		id: 'subagent'
		parent_session_id: request.parent_session_id
		agent_id: request.agent_id
		mode: if request.mode == 'fork' { 'fork' } else { 'isolated' }
		status: 'running'
		output: ''
		error: ''
		created_at: subagent_timestamp(stamp)
		updated_at: subagent_timestamp(stamp)
	}
	result := manager.runner(request) or {
		task.status = 'failed'
		task.error = subagent_error_code(err)
		task.updated_at = subagent_timestamp(manager.clock())
		return task
	}
	task.status = 'completed'
	task.output = result.output
	task.updated_at = subagent_timestamp(manager.clock())
	return task
}
