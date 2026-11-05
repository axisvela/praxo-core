function value = request(messages, tools)
if nargin < 2, tools = {}; end
value = struct('messages', {messages}, 'tools', {tools});
end
