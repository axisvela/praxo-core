function mcp_example()
    init = transport('initialize', struct());
    assert(strcmp(init.protocolVersion, '2024-11-05'));
    assert(strcmp(init.serverInfo.name, 'example-mcp'));

    tools = transport('tools/list', struct()).tools;
    assert(numel(tools) == 2);
    assert(strcmp(tools{1}.name, 'echo'));
    assert(strcmp(tools{2}.name, 'add'));

    result = transport('tools/call', struct('name', 'add'));
    assert(result.structuredContent.sum == 5);
    disp('MATLAB MCP example passed');
end

function result = transport(method, params)
    switch method
        case 'initialize'
            result = struct('protocolVersion', '2024-11-05', ...
                'serverInfo', struct('name', 'example-mcp'));
        case 'tools/list'
            result = struct('tools', {{ ...
                struct('name', 'echo', 'inputSchema', struct('type', 'object')), ...
                struct('name', 'add', 'inputSchema', struct('type', 'object')) ...
            }});
        case 'tools/call'
            result = struct('structuredContent', struct('sum', 5));
        otherwise
            result = struct();
    end
end
