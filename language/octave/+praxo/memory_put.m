function [store, record] = memory_put(store, session, record)
if ~isfield(record, 'id'), record.id = ''; end
if ~isfield(record, 'createdAt'), record.createdAt = ''; end
if isempty(record.id)
    record.id = sprintf('mem-%d-%d', fix(now * 86400), store.sequence);
    store.sequence = store.sequence + 1;
end
if isempty(record.createdAt)
    record.createdAt = num2str(fix(now * 86400));
end
index = find(strcmp(store.sessions, session), 1);
if isempty(index)
    store.sessions{end + 1} = session;
    store.records{end + 1} = {record};
else
    store.records{index}{end + 1} = record;
end
end
