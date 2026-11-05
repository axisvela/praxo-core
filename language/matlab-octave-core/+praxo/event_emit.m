function sink = event_emit(sink, event)
switch sink.mode
    case 'multi'
        for i = 1:numel(sink.sinks)
            sink.sinks{i} = praxo.event_emit(sink.sinks{i}, event);
        end
    case 'filter'
        if isempty(sink.predicate) || any(strcmp(event.kind, sink.predicate))
            sink.target = praxo.event_emit(sink.target, event);
        end
    otherwise
        sink.kinds{end + 1} = event.kind;
end
end
