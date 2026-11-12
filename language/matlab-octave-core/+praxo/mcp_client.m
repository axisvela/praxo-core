function client = mcp_client(transport, client_version, protocol_version)
if nargin < 2 || isempty(client_version)
    client_version = '0.4.0';
end
if nargin < 3 || isempty(protocol_version)
    protocol_version = '2024-11-05';
end
if ~isa(transport, 'function_handle')
    error('praxo:mcp', 'mcp: transport must be a function handle');
end
params = praxo.json_make_object({ ...
    'protocolVersion', praxo.json_make_string(protocol_version); ...
    'capabilities', praxo.json_make_object(cell(0, 2)); ...
    'clientInfo', praxo.json_make_object({ ...
        'name', praxo.json_make_string('praxo-core'); ...
        'version', praxo.json_make_string(client_version)})});
result = transport('initialize', params);
if ~isstruct(result) || ~isfield(result, 'kind') || ~strcmp(result.kind, 'object')
    error('praxo:mcp', 'mcp: initialize result must be an object');
end
[version, found] = praxo.json_field(result, 'protocolVersion');
if ~found || ~strcmp(version.kind, 'string') || isempty(version.value)
    error('praxo:mcp', 'mcp: initialize returned no protocol version');
end
[info, has_info] = praxo.json_field(result, 'serverInfo');
if ~has_info || ~strcmp(info.kind, 'object')
    info = praxo.json_make_object(cell(0, 2));
end
client = struct('transport', transport, ...
    'client_version', client_version, ...
    'protocol_version', version.value, ...
    'server_info', info, ...
    'closed', false);
end
