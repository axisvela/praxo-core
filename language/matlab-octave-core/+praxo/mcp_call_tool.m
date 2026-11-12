function value = mcp_call_tool(client, name, tool_arguments)
if nargin < 3 || isempty(tool_arguments)
    tool_arguments = praxo.json_make_object(cell(0, 2));
end
if ~isstruct(client) || ~isfield(client, 'transport')
    error('praxo:mcp', 'mcp: client is required');
end
if ~ischar(name) || isempty(name)
    error('praxo:mcp', 'mcp: tool name is required');
end
params = praxo.json_make_object({ ...
    'name', praxo.json_make_string(name); ...
    'arguments', tool_arguments});
result = client.transport('tools/call', params);
[is_error, has_error] = praxo.json_field(result, 'isError');
if has_error && strcmp(is_error.kind, 'boolean') && is_error.value
    error('praxo:mcp', sprintf('mcp: tool %s failed', name));
end
[structured, has_structured] = praxo.json_field(result, 'structuredContent');
if has_structured
    value = structured;
    return;
end
texts = {};
[content, has_content] = praxo.json_field(result, 'content');
if has_content && strcmp(content.kind, 'array')
    for i = 1:numel(content.value)
        item = content.value{i};
        [kind, has_kind] = praxo.json_field(item, 'type');
        [text, has_text] = praxo.json_field(item, 'text');
        if has_kind && strcmp(kind.kind, 'string') && ...
                strcmp(kind.value, 'text') && ...
                has_text && strcmp(text.kind, 'string')
            texts{end + 1} = text.value;
        end
    end
end
if isempty(texts)
    value = praxo.json_make_null();
elseif numel(texts) == 1
    value = praxo.json_make_string(texts{1});
else
    items = cell(1, numel(texts));
    for i = 1:numel(texts)
        items{i} = praxo.json_make_string(texts{i});
    end
    value = praxo.json_make_array(items);
end
end
