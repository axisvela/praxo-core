function ok = revoke(client, token)
if ~ischar(token) || isempty(token)
    error('praxo:service', 'SERVICE_AUTH: revocation token is required');
end
if ~isstruct(client) || ~isscalar(client) || ~isfield(client, 'transport') || ...
        ~isfield(client, 'endpoint') || ~isfield(client, 'client_id') || ...
        ~isfield(client, 'client_secret') || ~isfield(client, 'authorization')
    error('praxo:service', 'SERVICE_AUTH: token revocation failed');
end
form = struct( ...
    'token', token, ...
    'token_type_hint', 'access_token', ...
    'client_id', client.client_id, ...
    'client_secret', client.client_secret);
try
    response = client.transport(client.endpoint, form, client.authorization);
catch
    error('praxo:service', 'SERVICE_AUTH: token revocation failed');
end
if response_status(response) ~= 200
    error('praxo:service', 'SERVICE_AUTH: token revocation failed');
end
ok = true;
end

function status = response_status(response)
status = -1;
if ~isstruct(response) || ~isscalar(response) || ~isfield(response, 'status')
    return;
end
status = response.status;
if ischar(status)
    status = str2double(status);
end
if ~isnumeric(status) || ~isscalar(status) || ~isfinite(status)
    status = -1;
end
end
