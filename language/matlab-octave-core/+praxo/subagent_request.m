function value = subagent_request(parentSessionId, agentId, prompt, mode)
if nargin < 1 || isempty(parentSessionId), parentSessionId = ''; end
if nargin < 2 || isempty(agentId), agentId = ''; end
if nargin < 3 || isempty(prompt), prompt = ''; end
if nargin < 4 || isempty(mode), mode = 'isolated'; end
if ~strcmp(mode, 'fork')
    mode = 'isolated';
end
value = struct('parentSessionId', parentSessionId, 'agentId', agentId, ...
    'prompt', prompt, 'mode', mode);
end
