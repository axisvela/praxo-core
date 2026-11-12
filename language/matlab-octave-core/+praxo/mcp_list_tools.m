function tools = mcp_list_tools(client)
if ~isstruct(client) || ~isfield(client, 'transport')
    error('praxo:mcp', 'mcp: client is required');
end
tools = {};
names = {};
cursors = {};
cursor = '';
while true
    if isempty(cursor)
        params = praxo.json_make_object(cell(0, 2));
    else
        params = praxo.json_make_object({ ...
            'cursor', praxo.json_make_string(cursor)});
    end
    result = client.transport('tools/list', params);
    [raw, found] = praxo.json_field(result, 'tools');
    if ~found || ~strcmp(raw.kind, 'array')
        error('praxo:mcp', 'mcp: tools/list tools must be an array');
    end
    for i = 1:numel(raw.value)
        item = raw.value{i};
        [name, has_name] = praxo.json_field(item, 'name');
        if ~strcmp(item.kind, 'object') || ~has_name || ...
                ~strcmp(name.kind, 'string') || isempty(name.value)
            error('praxo:mcp', 'mcp: tool name is required');
        end
        if any(strcmp(names, name.value))
            error('praxo:mcp', sprintf('mcp: duplicate tool %s', name.value));
        end
        names{end + 1} = name.value;
        tools{end + 1} = item;
    end
    [next_cursor, has_next] = praxo.json_field(result, 'nextCursor');
    if ~has_next
        next_cursor = '';
    elseif ~strcmp(next_cursor.kind, 'string')
        error('praxo:mcp', 'mcp: nextCursor must be a string');
    else
        next_cursor = next_cursor.value;
    end
    if isempty(next_cursor)
        break;
    end
    if any(strcmp(cursors, next_cursor))
        error('praxo:mcp', 'mcp: repeated tool pagination cursor');
    end
    cursors{end + 1} = next_cursor;
    cursor = next_cursor;
end
end
