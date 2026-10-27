function value = decision(allowed, reason)
if nargin < 2, reason = ''; end
value = struct('allowed', logical(allowed), 'reason', reason);
end
