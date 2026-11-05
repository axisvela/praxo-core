function value = event(kind, sessionId, runId, data)
if nargin < 3, runId = ''; end
if nargin < 4, data = praxo.json_make_null(); end
value = struct('kind', kind, 'sessionId', sessionId, 'runId', runId, 'data', data);
end
