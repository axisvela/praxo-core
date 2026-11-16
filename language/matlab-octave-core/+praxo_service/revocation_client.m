function client = revocation_client(transport, endpoint, options)
if nargin < 3 || isempty(options)
    options = struct();
end
if ~isstruct(options) || ~isscalar(options)
    error('praxo:service', 'SERVICE_AUTH: options must be a struct');
end
client_id = '';
client_secret = '';
if isfield(options, 'client_id')
    client_id = options.client_id;
end
if isfield(options, 'client_secret')
    client_secret = options.client_secret;
end
client = struct( ...
    'transport', transport, ...
    'endpoint', endpoint, ...
    'client_id', client_id, ...
    'client_secret', client_secret, ...
    'authorization', praxo_service.basic_auth(client_id, client_secret));
end
