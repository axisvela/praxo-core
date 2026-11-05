function kinds = event_kinds(sink)
switch sink.mode
    case 'multi'
        kinds = cell(1, numel(sink.sinks));
        for i = 1:numel(sink.sinks)
            kinds{i} = praxo.event_kinds(sink.sinks{i});
        end
    case 'filter'
        kinds = praxo.event_kinds(sink.target);
    otherwise
        kinds = sink.kinds;
end
end
