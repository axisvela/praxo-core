function test_session()
options = praxo.agent_options(@turn_model);
options.maxSteps = 2;
options.messages = {struct('role', 'user', 'content', 'first'), ...
    struct('role', 'assistant', 'content', 'ack')};
result = praxo.agent_run('second', options.model, {}, options);
assert(isempty(result.errorCode) && strcmp(result.output, 'turn 3'));
assert(numel(result.messages) == 4);
assert(strcmp(result.messages{1}.content, 'first'));
assert(strcmp(result.messages{2}.content, 'ack'));
assert(strcmp(result.messages{3}.content, 'second'));
assert(strcmp(result.messages{4}.content, 'turn 3'));

options = praxo.agent_options(@turn_model);
options.maxSteps = 2;
options.messages = result.messages;
result = praxo.agent_run('third', options.model, {}, options);
assert(isempty(result.errorCode) && strcmp(result.output, 'turn 5'));
assert(numel(result.messages) == 6);
assert(strcmp(result.messages{5}.content, 'third'));
assert(strcmp(result.messages{6}.content, 'turn 5'));

disp('test_session passed');
end

function response = turn_model(request)
response = struct('content', sprintf('turn %d', numel(request.messages)));
end
