function test_delegation()
request = praxo.subagent_request('parent', 'child', 'look up', 'fork');
assert(strcmp(request.parentSessionId, 'parent'));
assert(strcmp(request.agentId, 'child'));
assert(strcmp(request.prompt, 'look up'));
assert(strcmp(request.mode, 'fork'));

result = praxo.subagent_result('task-1', 'child', 'done');
assert(strcmp(result.taskId, 'task-1'));
assert(strcmp(result.agentId, 'child'));
assert(strcmp(result.output, 'done'));

clock = @() struct('epochNanos', '1794294000000000000', ...
    'createdAt', '2026-11-10T07:00:00Z');
seen = [];
    function value = runner(subagentRequest)
        seen = subagentRequest;
        value = praxo.subagent_result('task-1', subagentRequest.agentId, 'done');
    end
task = praxo.subagent_run(@runner, request, clock);
assert(strcmp(task.id, 'subagent'));
assert(strcmp(task.parentSessionId, 'parent'));
assert(strcmp(task.agentId, 'child'));
assert(strcmp(task.mode, 'fork'));
assert(strcmp(task.status, 'completed'));
assert(strcmp(task.output, 'done'));
assert(isempty(task.error));
assert(strcmp(task.createdAt, '2026-11-10T07:00:00Z'));
assert(strcmp(task.updatedAt, '2026-11-10T07:00:00Z'));
assert(isequal(seen, request));

swapped = praxo.subagent_run(request, @runner, clock);
assert(strcmp(swapped.status, 'completed'));
assert(strcmp(swapped.output, 'done'));

task = praxo.subagent_run(@failing_runner, request, clock);
assert(strcmp(task.status, 'failed'));
assert(strcmp(task.output, ''));
assert(strcmp(task.error, 'BOOM'));

task = praxo.subagent_run(@generic_runner, request, clock);
assert(strcmp(task.status, 'failed'));
assert(strcmp(task.error, 'SUBAGENT_ERROR'));

task = praxo.subagent_run(@empty_runner, request, clock);
assert(strcmp(task.status, 'failed'));
assert(strcmp(task.error, 'SUBAGENT_ERROR'));

caught = false;
try
    praxo.subagent_run([], request, clock);
catch err
    caught = true;
    assert(~isempty(strfind(err.message, 'SUBAGENT_INVALID')));
end
assert(caught);

caught = false;
try
    praxo.subagent_run(@runner, praxo.subagent_request('', 'child', 'look up'), clock);
catch err
    caught = true;
    assert(~isempty(strfind(err.message, 'SUBAGENT_INVALID')));
end
assert(caught);

caught = false;
try
    praxo.subagent_run(@runner, praxo.subagent_request('parent', '', 'look up'), clock);
catch err
    caught = true;
    assert(~isempty(strfind(err.message, 'SUBAGENT_INVALID')));
end
assert(caught);

task = praxo.subagent_run(@runner, ...
    praxo.subagent_request('parent', 'child', 'look up', 'other'), clock);
assert(strcmp(task.mode, 'isolated'));
disp('test_delegation passed');
end

function value = failing_runner(request) %#ok<INUSD>
error('praxo:agent', 'BOOM: boom');
end

function value = generic_runner(request) %#ok<INUSD>
error('bad');
end

function value = empty_runner(request) %#ok<INUSD>
value = [];
end
