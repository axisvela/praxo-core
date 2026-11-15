function session_checkpoint_example()
store = containers.Map();
checkpoint = struct('id', 'cp-1', 'sessionId', 'session-1', 'runId', 'run-1', 'status', 'completed');
checkpoint.messages = {struct('role', 'user', 'content', 'first'), ...
    struct('role', 'assistant', 'content', 'ack')};
store('session-1') = checkpoint;

loaded = store('session-1');
options = praxo.agent_options(@turn_model);
options.maxSteps = 2;
options.sessionId = 'session-1';
options.messages = loaded.messages;
result = praxo.agent_run('second', options.model, {}, options);
assert(isempty(result.errorCode) && strcmp(result.output, 'turn 3'));

checkpoint = struct('id', 'cp-2', 'sessionId', 'session-1', 'runId', 'run-2', 'status', 'completed');
checkpoint.messages = result.messages;
store('session-1') = checkpoint;

loaded = store('session-1');
assert(numel(loaded.messages) == 4);
options = praxo.agent_options(@turn_model);
options.maxSteps = 2;
options.sessionId = 'session-1';
options.messages = loaded.messages;
result = praxo.agent_run('third', options.model, {}, options);
assert(isempty(result.errorCode) && strcmp(result.output, 'turn 5'));

fprintf('restored messages: %d\n', numel(loaded.messages));
fprintf('output: %s\n', result.output);
end

function response = turn_model(request)
response = struct('content', sprintf('turn %d', numel(request.messages)));
end
