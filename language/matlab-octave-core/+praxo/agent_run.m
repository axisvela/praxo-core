function result = agent_run(prompt, model, tools, options)
if nargin < 3 || isempty(tools), tools = {}; end
if nargin < 4 || isempty(options), options = struct(); end
if ~ischar(prompt) || ~isa(model, 'function_handle') || ~iscell(tools) || ~isstruct(options) || ~isscalar(options)
    error('praxo:agent', 'Invalid agent configuration');
end
require_policy = logical(option(options, 'requirePolicy', false));
require_tool_scope = logical(option(options, 'requireToolScope', false));
has_policy = isfield(options, 'policy') && ~isempty(options.policy);
if require_policy && ~has_policy
    error('praxo:AGENT_INVALID_OPTIONS', ...
        'agent: require policy: policy is required');
end
allowed_tools = option(options, 'allowedTools', {});
if require_tool_scope && isempty(allowed_tools)
    error('praxo:AGENT_INVALID_OPTIONS', ...
        'agent: require tool scope: allowedTools must not be empty');
end
max_steps = option(options, 'maxSteps', 8);
max_tokens = option(options, 'maxTokens', 0);
if ~valid_limit(max_steps) || max_steps < 1 || ~valid_limit(max_tokens)
    error('praxo:agent', 'Invalid agent budget');
end
session_id = option(options, 'sessionId', 's1');
if ~ischar(session_id) || isempty(session_id), session_id = 's1'; end
interrupt_on = option(options, 'interruptOn', {});
if ischar(interrupt_on), interrupt_on = {interrupt_on}; end
if ~iscell(interrupt_on)
    error('praxo:agent', 'Invalid interrupt configuration');
end
on_decision = [];
if isfield(options, 'onInterruptDecision'), on_decision = options.onInterruptDecision; end
on_interrupt = [];
if isfield(options, 'onInterrupt'), on_interrupt = options.onInterrupt; end
if ~isempty(on_decision) && ~isa(on_decision, 'function_handle')
    error('praxo:agent', 'Invalid interrupt decision handler');
end
if ~isempty(on_interrupt) && ~isa(on_interrupt, 'function_handle')
    error('praxo:agent', 'Invalid interrupt approval handler');
end
selection = [];
if isfield(options, 'toolSelection'), selection = options.toolSelection; end
pii = false;
if isfield(options, 'pii'), pii = logical(options.pii); end
structured = [];
if isfield(options, 'structuredOutput'), structured = options.structuredOutput; end
limit = [];
if isfield(options, 'callLimit') && ~isempty(options.callLimit) && isstruct(options.callLimit)
    limit = options.callLimit;
    limit.models = 0;
    limit.tools = 0;
end
names = cell(1, numel(tools));
specs = cell(1, numel(tools));
for i = 1:numel(tools)
    tool = tools{i};
    if ~isstruct(tool) || ~isscalar(tool) || ~isfield(tool, 'name') || ~ischar(tool.name) || isempty(tool.name) || ...
            ~isfield(tool, 'invoke') || ~isa(tool.invoke, 'function_handle') || any(strcmp(names(1:i-1), tool.name))
        error('praxo:agent', 'Invalid or duplicate tool');
    end
    names{i} = tool.name;
    specs{i} = struct('name', tool.name, 'description', option(tool, 'description', ''));
end
messages = option(options, 'messages', {});
if isempty(messages) && isfield(options, 'history'), messages = options.history; end
if ~iscell(messages)
    error('praxo:agent', 'Invalid session history');
end
messages{end+1} = struct('role', 'user', 'content', prompt);
result = struct('output', '', 'steps', 0, 'inputTokens', 0, 'outputTokens', 0, ...
    'runId', 'run-1', 'sessionId', session_id, ...
    'events', {{'run.started'}}, 'toolInvocations', 0, 'errorCode', '', 'errorMessage', '', 'messages', {messages});
for step = 1:max_steps
    advertised = specs;
    if ~isempty(allowed_tools)
        advertised = specs(cellfun(@(spec) any(strcmp(allowed_tools, spec.name)), specs));
    end
    if ~isempty(selection), advertised = praxo.select_tools(selection, advertised); end
    [allowed, reason] = authorize(options, 'model.generate', session_id, '', praxo.json_make_null());
    if ~allowed
        result = fail(result, 'AGENT_POLICY_DENIED', policy_message('model.generate', reason));
        return;
    end
    if ~isempty(limit)
        [limit, code] = praxo.call_limit_model(limit);
        if ~isempty(code)
            result = fail(result, code, 'Model call limit exceeded');
            return;
        end
    end
    request_messages = messages;
    if pii, request_messages = redact_messages(messages); end
    try
        request_value = struct('messages', {request_messages}, 'tools', {advertised});
        on_delta = option(options, 'onDelta', []);
        if ~isempty(on_delta)
            request_value.onDelta = on_delta;
        end
        response = model(request_value);
        if ~isstruct(response) || ~isscalar(response) || ~isfield(response, 'content') || ~ischar(response.content)
            error('praxo:agent', 'Invalid model response');
        end
        input_tokens = option(response, 'inputTokens', 0);
        output_tokens = option(response, 'outputTokens', 0);
        calls = option(response, 'toolCalls', {});
        if ~valid_limit(input_tokens) || ~valid_limit(output_tokens) || ~iscell(calls)
            error('praxo:agent', 'Invalid model response');
        end
    catch err
        result = fail(result, 'MODEL_ERROR', err.message);
        return;
    end
    result.steps = step;
    result.inputTokens = result.inputTokens + input_tokens;
    result.outputTokens = result.outputTokens + output_tokens;
    if max_tokens > 0 && result.inputTokens + result.outputTokens > max_tokens
        result = fail(result, 'AGENT_MAX_TOKENS', 'Token budget exceeded');
        return;
    end
    messages{end+1} = struct('role', 'assistant', 'content', response.content, 'toolCalls', {calls});
    result.messages = messages;
    if isempty(calls)
        output = response.content;
        if ~isempty(structured)
            [output, code] = praxo.structured_apply(structured, response.content);
            if ~isempty(code)
                result = fail(result, code, 'Structured output failed');
                return;
            end
        end
        result.output = output;
        result.events{end+1} = 'run.completed';
        return;
    end
    for i = 1:numel(calls)
        call = calls{i};
        if ~isstruct(call) || ~isscalar(call) || ~isfield(call, 'id') || ~ischar(call.id) || ...
                ~isfield(call, 'name') || ~ischar(call.name) || ~isfield(call, 'arguments') || ...
                ~isstruct(call.arguments) || ~isscalar(call.arguments) || ~isfield(call.arguments, 'kind') || ...
                ~ischar(call.arguments.kind) || ~strcmp(call.arguments.kind, 'object') || ~isfield(call.arguments, 'value')
            result = fail(result, 'MODEL_ERROR', 'Invalid tool call');
            return;
        end
        try
            praxo.encode_json(call.arguments);
        catch err
            result = fail(result, 'MODEL_ERROR', err.message);
            return;
        end
        if ~isempty(selection)
            code = praxo.check_tool_selected(selection, call.name);
            if ~isempty(code)
                result = fail(result, code, 'Tool not selected');
                return;
            end
        end
        index = find(strcmp(names, call.name), 1);
        if isempty(index)
            result = fail(result, 'TOOL_NOT_FOUND', 'Tool not found');
            return;
        end
        if ~isempty(allowed_tools) && ~any(strcmp(allowed_tools, call.name))
            result = fail(result, 'AGENT_TOOL_NOT_ALLOWED', ...
                ['agent: tool ' call.name ' is not allowed']);
            return;
        end
        [allowed, reason] = authorize(options, 'tool.invoke', session_id, call.name, call.arguments);
        if ~allowed
            result = fail(result, 'AGENT_POLICY_DENIED', policy_message('tool.invoke', reason));
            return;
        end
        if ~isempty(limit)
            [limit, code] = praxo.call_limit_tool(limit);
            if ~isempty(code)
                result = fail(result, code, 'Tool call limit exceeded');
                return;
            end
        end
        skipped = false;
        content = '';
        if any(strcmp(interrupt_on, call.name))
            if isempty(on_decision) && isempty(on_interrupt)
                result = fail(result, 'AGENT_INTERRUPT_UNHANDLED', ...
                    ['agent: approval handler not configured: ' call.name]);
                return;
            end
            result.events{end+1} = 'tool.interrupt';
            interrupt = struct('runId', result.runId, 'sessionId', session_id, 'call', call);
            if ~isempty(on_decision)
                decision = on_decision(interrupt);
                if ~isstruct(decision) || ~isscalar(decision) || ~isfield(decision, 'action') || ~ischar(decision.action)
                    result = fail(result, 'AGENT_INTERRUPT_DECISION_INVALID', ...
                        'agent: invalid interrupt decision');
                    return;
                end
                switch decision.action
                    case 'approve'
                    case 'edit'
                        if ~isfield(decision, 'arguments') || ~isstruct(decision.arguments) || ...
                                ~isscalar(decision.arguments) || ~isfield(decision.arguments, 'kind') || ...
                                ~ischar(decision.arguments.kind) || ~strcmp(decision.arguments.kind, 'object') || ...
                                ~isfield(decision.arguments, 'value')
                            result = fail(result, 'AGENT_INTERRUPT_DECISION_INVALID', ...
                                'agent: edit requires arguments');
                            return;
                        end
                        try
                            praxo.encode_json(decision.arguments);
                        catch err
                            result = fail(result, 'AGENT_INTERRUPT_DECISION_INVALID', ...
                                'agent: edit requires arguments');
                            return;
                        end
                        call.arguments = decision.arguments;
                        [allowed, reason] = authorize(options, 'tool.invoke', session_id, call.name, call.arguments);
                        if ~allowed
                            result = fail(result, 'AGENT_POLICY_DENIED', ...
                                policy_message('tool.invoke', reason));
                            return;
                        end
                    case 'reject'
                        reason = '';
                        if isfield(decision, 'reason') && ischar(decision.reason)
                            reason = decision.reason;
                        end
                        result = fail(result, 'AGENT_APPROVAL_DENIED', ...
                            ['agent: tool call denied by approval: ' call.name ': ' reason]);
                        return;
                    case 'respond'
                        response_text = '';
                        if isfield(decision, 'response') && ischar(decision.response)
                            response_text = decision.response;
                        end
                        skipped = true;
                        content = praxo.encode_json(praxo.json_make_string(response_text));
                    otherwise
                        result = fail(result, 'AGENT_INTERRUPT_DECISION_INVALID', ...
                            ['agent: invalid interrupt decision: ' decision.action]);
                        return;
                end
            else
                approved = on_interrupt(interrupt);
                if ~islogical(approved) || ~isscalar(approved)
                    error('praxo:agent', 'Invalid interrupt approval');
                end
                if ~approved
                    result = fail(result, 'AGENT_APPROVAL_DENIED', ...
                        ['agent: tool call denied by approval: ' call.name]);
                    return;
                end
            end
        end
        if ~skipped
            result.events{end+1} = 'tool.call';
            result.toolInvocations = result.toolInvocations + 1;
            try
                value = tools{index}.invoke(call.arguments);
                if pii, value = praxo.redact_value(value); end
                content = praxo.encode_json(value);
            catch err
                result = fail(result, 'TOOL_ERROR', err.message);
                return;
            end
        end
        messages{end+1} = struct('role', 'tool', 'content', content, 'toolCallId', call.id);
        result.messages = messages;
    end
end
result = fail(result, 'AGENT_MAX_STEPS', 'Maximum steps exceeded');
end

function output = redact_messages(messages)
output = messages;
for i = 1:numel(output)
    output{i}.content = praxo.pii_redact(output{i}.content);
    if isfield(output{i}, 'contentBlocks')
        for j = 1:numel(output{i}.contentBlocks)
            if isfield(output{i}.contentBlocks{j}, 'text') && ~isempty(output{i}.contentBlocks{j}.text)
                output{i}.contentBlocks{j}.text = praxo.pii_redact(output{i}.contentBlocks{j}.text);
            end
        end
    end
    if isfield(output{i}, 'toolCalls')
        for j = 1:numel(output{i}.toolCalls)
            if isfield(output{i}.toolCalls{j}, 'arguments')
                output{i}.toolCalls{j}.arguments = praxo.redact_value(output{i}.toolCalls{j}.arguments);
            end
        end
    end
end
end

function [allowed, reason] = authorize(options, kind, session_id, tool_name, arguments)
allowed = true;
reason = '';
if ~isfield(options, 'policy') || isempty(options.policy), return; end
action = struct('kind', kind, 'sessionId', session_id, 'toolName', tool_name, 'arguments', arguments);
decision = options.policy(action);
if islogical(decision) && isscalar(decision)
    allowed = decision;
elseif isstruct(decision) && isscalar(decision) && isfield(decision, 'allowed') && ...
        islogical(decision.allowed) && isscalar(decision.allowed)
    allowed = decision.allowed;
    if isfield(decision, 'reason') && ischar(decision.reason)
        reason = decision.reason;
    end
else
    error('praxo:agent', 'Invalid policy decision');
end
end

function message = policy_message(kind, reason)
message = ['agent: ' kind ' denied'];
if ~isempty(reason), message = [message ': ' reason]; end
end

function value = option(record, name, fallback)
if isfield(record, name), value = record.(name); else, value = fallback; end
end

function valid = valid_limit(value)
valid = isnumeric(value) && isreal(value) && isscalar(value) && isfinite(value) && value >= 0 && value == fix(value);
end

function result = fail(result, code, message)
result.errorCode = code;
result.errorMessage = message;
result.events{end+1} = 'run.failed';
end
