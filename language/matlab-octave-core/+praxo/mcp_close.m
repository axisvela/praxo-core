function client = mcp_close(client)
if isstruct(client) && isfield(client, 'closed')
    client.closed = true;
end
end
