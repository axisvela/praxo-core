function records = memory_search(store, session, query, limit)
records = {};
index = find(strcmp(store.sessions, session), 1);
if isempty(index)
    return;
end
candidates = store.records{index};
needle = lower(strtrim(query));
kept = {};
for i = 1:numel(candidates)
    if isempty(needle) || ~isempty(strfind(lower(candidates{i}.content), needle))
        kept{end + 1} = candidates{i};
    end
end
if ~isempty(kept)
    keys = cell(1, numel(kept));
    for i = 1:numel(kept), keys{i} = kept{i}.createdAt; end
    [~, order] = sort(keys, 'descend');
    kept = kept(order);
end
if limit > 0 && numel(kept) > limit
    kept = kept(1:limit);
end
records = kept;
end
