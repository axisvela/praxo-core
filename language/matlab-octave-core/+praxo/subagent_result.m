function value = subagent_result(taskId, agentId, output)
if nargin < 1 || isempty(taskId), taskId = ''; end
if nargin < 2 || isempty(agentId), agentId = ''; end
if nargin < 3 || isempty(output), output = ''; end
value = struct('taskId', taskId, 'agentId', agentId, 'output', output);
end
