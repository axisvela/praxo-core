function result = agent_run(prompt, model, tools, options)
if nargin < 3 || isempty(tools), tools = {}; end
if nargin < 4 || isempty(options), options = struct(); end
if ~ischar(prompt) || ~isa(model, 'function_handle') || ~iscell(tools) || ~isstruct(options) || ~isscalar(options)
    error('praxo:agent', 'Invalid agent configuration');
end
max_steps = option(options, 'maxSteps', 8);
max_tokens = option(options, 'maxTokens', 0);
if ~valid_limit(max_steps) || max_steps < 1 || ~valid_limit(max_tokens)
    error('praxo:agent', 'Invalid agent budget');
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
messages = {struct('role', 'user', 'content', prompt)};
result = struct('output', '', 'steps', 0, 'inputTokens', 0, 'outputTokens', 0, ...
    'events', {{'run.started'}}, 'toolInvocations', 0, 'errorCode', '', 'errorMessage', '', 'messages', {messages});
for step = 1:max_steps
    advertised = specs;
    if ~isempty(selection), advertised = praxo.select_tools(selection, specs); end
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
        response = model(struct('messages', {request_messages}, 'tools', {advertised}));
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
        if ~isempty(limit)
            [limit, code] = praxo.call_limit_tool(limit);
            if ~isempty(code)
                result = fail(result, code, 'Tool call limit exceeded');
                return;
            end
        end
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
