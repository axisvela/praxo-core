function sink = otel_sink(endpoint, serviceName, allowedDataKeys, transport, clock)
if nargin < 2 || isempty(serviceName), serviceName = 'praxo-core'; end
if nargin < 3 || isempty(allowedDataKeys), allowedDataKeys = {}; end
if nargin < 4, transport = []; end
if nargin < 5, clock = []; end
if ischar(allowedDataKeys)
    allowedDataKeys = {allowedDataKeys};
end
if ~iscell(allowedDataKeys)
    allowedDataKeys = {};
end
sink = struct('endpoint', endpoint, 'serviceName', serviceName, ...
    'allowedDataKeys', {allowedDataKeys}, 'transport', transport, 'clock', clock);
end
