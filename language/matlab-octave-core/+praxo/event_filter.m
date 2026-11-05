function sink = event_filter(target, predicate)
sink = struct('mode', 'filter', 'target', target, 'predicate', {predicate});
end
