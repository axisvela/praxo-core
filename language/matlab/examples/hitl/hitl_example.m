function hitl_example()
seen = containers.Map();
seen('calls') = {};
tool = praxo.tool('echo', 'Echo', @(args) capture(args, seen));

run_approve(tool, seen);
run_edit_denied(tool, seen);
run_reject(tool, seen);
run_respond(tool, seen);
run_unhandled(tool, seen);
run_invalid(tool, seen);
disp('MATLAB HITL example passed');
end

function run_approve(tool, seen)
seen('calls') = {};
options = praxo.agent_options(scripted({tool_response(), struct('content', 'final')}));
options.interruptOn = {'echo'};
options.onInterruptDecision = @(interrupt) struct('action', 'approve');
result = praxo.agent_run('go', options.model, {tool}, options);
assert(isempty(result.errorCode) && strcmp(result.output, 'final'));
calls = seen('calls');
assert(numel(calls) == 1);
[value, found] = praxo.json_field(calls{1}, 'value');
assert(found && strcmp(value.value, 'original'));
assert(isequal(result.events, {'run.started', 'tool.interrupt', 'tool.call', 'run.completed'}));
end

function run_edit_denied(tool, seen)
seen('calls') = {};
seen('actions') = {};
options = praxo.agent_options(scripted({tool_response(), struct('content', 'final')}));
options.interruptOn = {'echo'};
options.policy = @(action) policy_decision(action, seen);
options.onInterruptDecision = @(interrupt) struct('action', 'edit', ...
    'arguments', praxo.parse_json('{"value":"edited"}'));
result = praxo.agent_run('go', options.model, {tool}, options);
assert(strcmp(result.errorCode, 'AGENT_POLICY_DENIED'));
assert(isempty(seen('calls')));
actions = seen('actions');
assert(numel(actions) == 2);
[first, found] = praxo.json_field(actions{1}.arguments, 'value');
[second, found2] = praxo.json_field(actions{2}.arguments, 'value');
assert(found && found2 && strcmp(first.value, 'original') && strcmp(second.value, 'edited'));
end

function run_reject(tool, seen)
seen('calls') = {};
options = praxo.agent_options(scripted({tool_response(), struct('content', 'final')}));
options.interruptOn = {'echo'};
options.onInterruptDecision = @(interrupt) struct('action', 'reject', 'reason', 'not allowed');
result = praxo.agent_run('go', options.model, {tool}, options);
assert(strcmp(result.errorCode, 'AGENT_APPROVAL_DENIED'));
assert(isempty(seen('calls')));
end

function run_respond(tool, seen)
seen('calls') = {};
options = praxo.agent_options(scripted({tool_response(), struct('content', '"human answer"')}));
options.interruptOn = {'echo'};
options.onInterruptDecision = @(interrupt) struct('action', 'respond', 'response', 'human answer');
result = praxo.agent_run('go', options.model, {tool}, options);
assert(isempty(result.errorCode) && strcmp(result.output, '"human answer"'));
assert(isempty(seen('calls')));
assert(isequal(result.events, {'run.started', 'tool.interrupt', 'run.completed'}));
end

function run_unhandled(tool, seen)
seen('calls') = {};
options = praxo.agent_options(scripted({tool_response(), struct('content', 'final')}));
options.interruptOn = {'echo'};
result = praxo.agent_run('go', options.model, {tool}, options);
assert(strcmp(result.errorCode, 'AGENT_INTERRUPT_UNHANDLED'));
assert(isempty(seen('calls')));
end

function run_invalid(tool, seen)
seen('calls') = {};
options = praxo.agent_options(scripted({tool_response(), struct('content', 'final')}));
options.interruptOn = {'echo'};
options.onInterruptDecision = @(interrupt) struct('action', 'invalid');
result = praxo.agent_run('go', options.model, {tool}, options);
assert(strcmp(result.errorCode, 'AGENT_INTERRUPT_DECISION_INVALID'));
assert(isempty(seen('calls')));
end

function value = capture(args, seen)
calls = seen('calls');
calls{end+1} = args;
seen('calls') = calls;
value = args;
end

function decision = policy_decision(action, seen)
decision = true;
if ~strcmp(action.kind, 'tool.invoke'), return; end
actions = seen('actions');
actions{end+1} = action;
seen('actions') = actions;
[value, found] = praxo.json_field(action.arguments, 'value');
if found && strcmp(value.value, 'edited')
    decision = praxo.decision(false, 'edited denied');
else
    decision = praxo.decision(true);
end
end

function response = tool_response()
call = struct('id', 'call-1', 'name', 'echo', ...
    'arguments', praxo.json_make_object({'value', praxo.json_make_string('original')}));
response = struct('content', '', 'toolCalls', {{call}});
end

function model = scripted(steps)
index = 0;
model = @next;
    function response = next(request)
        assert(isfield(request, 'messages') && isfield(request, 'tools'));
        index = index + 1;
        if index > numel(steps), error('test:exhausted', 'Script exhausted'); end
        response = steps{index};
    end
end
