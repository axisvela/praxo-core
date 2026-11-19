function test_plugin_process()
root = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
fixture = fullfile(root, 'language', 'c', 'tests', 'fixtures', 'process_plugin.py');
python = getenv('PRAXO_PYTHON');
if isempty(python)
    python = 'python3';
    if ispc
        python = 'python';
    end
end
config = struct('plugin_id', 'com.example.echo', 'path', python, ...
    'args', {{fixture}});
host = praxo.PluginProcess(config);
cleanup = onCleanup(@() host.stop());
assert(strcmp(host.invoke('tool.provider', 'echo', '{"text":"hi"}'), ...
    '{"text":"hi"}'));
assert(strcmp(host.invoke('tool.provider', 'echo', 'hello'), 'hello'));
try
    host.invoke('tool.provider', 'denied', '');
    error('test:missing', 'Expected denial');
catch failure
    assert(strcmp(failure.identifier, 'praxo:pluginCall'));
    assert(strcmp(failure.message, 'CAPABILITY_DENIED'));
end
assert(host.active);
assert(strcmp(host.invoke('tool.provider', 'echo', ''), ''));
for timeout = [0, -1, Inf, NaN]
    try
        host.invoke('tool.provider', 'echo', '', timeout);
        error('test:missing', 'Expected invalid timeout rejection');
    catch failure
        assert(strcmp(failure.identifier, 'praxo:plugin'));
    end
    assert(host.active);
end
try
    host.invoke('tool.provider', 'block', '', 0.1);
    error('test:missing', 'Expected timeout');
catch failure
    assert(strcmp(failure.identifier, 'praxo:pluginTimeout'));
end
assert(~host.active);
host.stop();
host.stop();
assert(~host.active);
try
    host.invoke('tool.provider', 'echo', '');
    error('test:missing', 'Expected stopped host rejection');
catch failure
    assert(strcmp(failure.identifier, 'praxo:plugin'));
end
failureFixture = fullfile(fileparts(mfilename('fullpath')), ...
    'fixtures', 'plugin_process_failure.py');
for mode = {'exit', 'stall'}
    failing = config;
    failing.args = {failureFixture, mode{1}};
    failing.start_timeout = 0.1;
    started = tic;
    try
        praxo.PluginProcess(failing);
        error('test:missing', 'Expected startup failure');
    catch failure
        assert(~strcmp(failure.identifier, 'test:missing'));
    end
    assert(toc(started) < 5);
end
for mode = {'wrong-id', 'wrong-version', 'bad-ok', 'bad-base64', ...
        'bad-json', 'partial', 'exit-after-health'}
    failing = config;
    failing.args = {failureFixture, mode{1}};
    broken = praxo.PluginProcess(failing);
    brokenCleanup = onCleanup(@() broken.stop());
    try
        broken.invoke('tool.provider', 'echo', '', 0.1);
        error('test:missing', 'Expected protocol failure');
    catch failure
        assert(~strcmp(failure.identifier, 'test:missing'));
    end
    assert(~broken.active);
    broken.stop();
    broken.stop();
    clear brokenCleanup;
end
normal = praxo.PluginProcess(config);
normalCleanup = onCleanup(@() normal.stop());
assert(normal.active);
normal.stop();
normal.stop();
assert(~normal.active);
disp('Octave Java process host tests passed');
end
