function call = parse_tool_call(content)
if ~ischar(content) || (~isrow(content) && ~isempty(content))
    error('praxo:toolcall', 'Content must be a character row vector');
end
call = [];
if numel(content) > 262144
    error('praxo:toolcall', 'Content exceeds capacity');
end
node = parse_object(content);
if ~isempty(node)
    name = [];
    input = struct('kind', 'object', 'value', {cell(0, 2)});
    valid = true;
    metadata = struct('operation', '', 'resource', '', 'risk', '', 'reason', '', 'idempotency_key', '');
    for i = 1:size(node.value, 1)
        key = node.value{i, 1};
        value = node.value{i, 2};
        if strcmp(key, 'name')
            if strcmp(value.kind, 'string')
                name = value.value;
            else
                valid = false;
            end
        elseif strcmp(key, 'input')
            if strcmp(value.kind, 'object')
                input = value;
            else
                valid = false;
            end
        elseif isfield(metadata, key)
            if strcmp(value.kind, 'string')
                metadata.(key) = value.value;
            elseif ~strcmp(value.kind, 'null')
                valid = false;
            end
        end
    end
    if valid && ~isempty(name)
        call = struct('name', name, 'input', input, 'metadata', metadata);
        return;
    end
end
patterns = {'(?s)<tool_call\s+name="([^"]+)"\s*>\s*(.*?)\s*</tool_call>', ...
    '(?s)<([a-zA-Z][\w-]*(?:\.[\w-]+)+)>\s*(\{.*?)\s*(?:</[a-zA-Z][\w.-]*>|$)', ...
    '(?m)^\s*([a-zA-Z][\w.-]*)\s+(\{[^\r\n]*\})\s*$'};
for i = 1:numel(patterns)
    matches = regexp(content, patterns{i}, 'tokens');
    if isempty(matches)
        continue;
    end
    match = matches{end};
    if i == 3 && isempty(strfind(match{1}, '.'))
        continue;
    end
    input = parse_object(match{2});
    if isempty(input)
        input = parse_object(strrep(match{2}, '\', '\\'));
    end
    if ~isempty(input)
        metadata = struct('operation', '', 'resource', '', 'risk', '', 'reason', '', 'idempotency_key', '');
        call = struct('name', match{1}, 'input', input, 'metadata', metadata);
        return;
    end
    return;
end
end

function node = parse_object(raw)
node = [];
try
    parsed = praxo.parse_json(raw);
    if strcmp(parsed.kind, 'object')
        node = parsed;
    end
catch err
    if ~strcmp(err.identifier, 'praxo:json')
        rethrow(err);
    end
end
end
