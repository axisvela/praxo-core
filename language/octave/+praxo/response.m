function value = response(message, usage)
if nargin < 2, usage = praxo.usage(0, 0); end
value = struct('message', message, 'usage', usage);
end
