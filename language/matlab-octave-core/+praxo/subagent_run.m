function task = subagent_run(runner, request, clock)
if nargin < 3, clock = []; end
if isstruct(runner) && isscalar(runner) && isa(request, 'function_handle')
    swap = runner;
    runner = request;
    request = swap;
end
if ~isa(runner, 'function_handle')
    error('praxo:delegation', 'SUBAGENT_INVALID: agent: subagent runner is required');
end
if ~isstruct(request) || ~isscalar(request)
    error('praxo:delegation', 'SUBAGENT_INVALID: agent: invalid subagent request');
end
parent = field_text(request, 'parentSessionId');
agent = field_text(request, 'agentId');
if isempty(parent) || isempty(agent)
    error('praxo:delegation', 'SUBAGENT_INVALID: agent: subagent parent session and agent id are required');
end
mode = field_text(request, 'mode');
if ~strcmp(mode, 'fork'), mode = 'isolated'; end
created = timestamp(clock);
try
    result = runner(request);
    if ~isstruct(result) || ~isscalar(result) || ~isfield(result, 'output') || ...
            ~ischar(result.output)
        task = praxo.subagent_task('subagent', parent, agent, mode, 'failed', '', ...
            'SUBAGENT_ERROR', created, timestamp(clock));
        return;
    end
    task = praxo.subagent_task('subagent', parent, agent, mode, 'completed', ...
        result.output, '', created, timestamp(clock));
catch caught
    task = praxo.subagent_task('subagent', parent, agent, mode, 'failed', '', ...
        error_code(caught), created, timestamp(clock));
end
end

function text = field_text(record, name)
text = '';
if isfield(record, name) && ischar(record.(name))
    text = record.(name);
end
end

function code = error_code(caught)
code = 'SUBAGENT_ERROR';
if ~isstruct(caught) || ~isfield(caught, 'message') || ~ischar(caught.message)
    return;
end
index = find(caught.message == ':', 1);
if ~isempty(index)
    candidate = strtrim(caught.message(1:index - 1));
    if ~isempty(regexp(candidate, '^[A-Z][A-Z0-9_]*$', 'once'))
        code = candidate;
        return;
    end
end
if isfield(caught, 'identifier') && ischar(caught.identifier) && ...
        ~isempty(regexp(caught.identifier, '^[A-Z][A-Z0-9_]*$', 'once'))
    code = caught.identifier;
end
end

function value = timestamp(clock)
if isempty(clock)
    seconds = (now() - 719529) * 86400;
    value = format_timestamp(seconds, 0);
    return;
end
parts = clock();
if isstruct(parts) && isfield(parts, 'createdAt') && ischar(parts.createdAt)
    value = parts.createdAt;
    return;
end
if isstruct(parts) && isfield(parts, 'epochNanos')
    nanos = double(parts.epochNanos);
    seconds = floor(nanos / 1e9);
    value = format_timestamp(seconds, nanos - seconds * 1e9);
    return;
end
if isstruct(parts) && isfield(parts, 'seconds')
    seconds = parts.seconds;
    nanos = 0;
    if isfield(parts, 'nanos'), nanos = parts.nanos; end
    value = format_timestamp(seconds, nanos);
    return;
end
if isnumeric(parts) && isscalar(parts)
    value = format_timestamp(parts, 0);
    return;
end
error('praxo:delegation', 'SUBAGENT_ERROR: agent: invalid clock');
end

function value = format_timestamp(seconds, nanos)
whole = floor(seconds);
fraction = round(nanos);
if fraction >= 1e9
    whole = whole + 1;
    fraction = fraction - 1e9;
end
vector = datevec(whole / 86400 + 719529);
value = sprintf('%04d-%02d-%02dT%02d:%02d:%02d.%09dZ', ...
    vector(1), vector(2), vector(3), vector(4), vector(5), round(vector(6)), fraction);
end
