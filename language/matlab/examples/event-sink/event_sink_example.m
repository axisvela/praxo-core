all_sink = praxo.event_new();
tool_sink = praxo.event_new();
filtered = praxo.event_filter(tool_sink, {'tool.call'});
multi = praxo.event_multi({all_sink, filtered});
for kind = {'run.started', 'tool.call', 'run.completed'}
    multi = praxo.event_emit(multi, praxo.event(kind{1}, 's1', '', []));
end
all_kinds = praxo.event_kinds(multi.sinks{1});
tool_kinds = praxo.event_kinds(multi.sinks{2});
assert(isequal(all_kinds, {'run.started', 'tool.call', 'run.completed'}));
assert(isequal(tool_kinds, {'tool.call'}));
disp('MATLAB event sink example passed');
