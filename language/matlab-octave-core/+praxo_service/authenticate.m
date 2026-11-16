function principal = authenticate(authenticator, authorization, now_seconds)
principal = [];
if ~isstruct(authenticator) || ~isscalar(authenticator) || ...
        ~isfield(authenticator, 'transport') || ~isfield(authenticator, 'endpoint') || ...
        ~isfield(authenticator, 'client_id') || ~isfield(authenticator, 'client_secret') || ...
        ~isfield(authenticator, 'tenant_claim') || ~isfield(authenticator, 'authorization')
    return;
end
if ~ischar(authorization) || ~isrow(authorization) || numel(authorization) < 7 || ...
        ~strcmp(authorization(1:7), 'Bearer ')
    return;
end
token = strtrim(authorization(8:end));
if isempty(token)
    return;
end
if nargin < 3 || isempty(now_seconds)
    now_seconds = floor((now() - 719529) * 86400);
end
if ~isnumeric(now_seconds) || ~isscalar(now_seconds) || ~isfinite(now_seconds)
    return;
end
form = struct( ...
    'token', token, ...
    'client_id', authenticator.client_id, ...
    'client_secret', authenticator.client_secret);
try
    response = authenticator.transport(authenticator.endpoint, form, ...
        authenticator.authorization);
catch
    return;
end
if ~isstruct(response) || ~isscalar(response) || ...
        ~isfield(response, 'status') || ~isfield(response, 'body')
    return;
end
status = response.status;
if ischar(status)
    status = str2double(status);
end
if ~isnumeric(status) || ~isscalar(status) || ~isfinite(status) || status ~= 200
    return;
end
if ~ischar(response.body)
    return;
end
try
    payload = praxo.parse_json(response.body);
catch
    return;
end
if ~isstruct(payload) || ~isscalar(payload) || ~isfield(payload, 'kind') || ...
        ~strcmp(payload.kind, 'object')
    return;
end
[active, found] = praxo.json_field(payload, 'active');
if ~found || ~isstruct(active) || ~strcmp(active.kind, 'boolean') || ~active.value
    return;
end
[subject, found] = praxo.json_field(payload, 'sub');
if ~found || ~strcmp(subject.kind, 'string') || isempty(subject.value)
    return;
end
[tenant, found] = praxo.json_field(payload, authenticator.tenant_claim);
if ~found || ~strcmp(tenant.kind, 'string') || isempty(tenant.value)
    return;
end
[expires, found] = praxo.json_field(payload, 'exp');
if ~found || ~strcmp(expires.kind, 'number') || expires.value ~= fix(expires.value) || ...
        expires.value <= now_seconds
    return;
end
principal = praxo_service.principal(subject.value, tenant.value, expires.value);
end
