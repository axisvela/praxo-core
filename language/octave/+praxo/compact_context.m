function [output, ok] = compact_context(budget, messages)
if budget.maxTokens <= 0 || praxo.estimate_tokens(messages) <= budget.maxTokens
    output = messages;
    ok = true;
    return;
end
system = {};
rest = {};
for i = 1:numel(messages)
    if strcmp(messages{i}.role, 'system')
        system{end + 1} = messages{i};
    else
        rest{end + 1} = messages{i};
    end
end
system = system(~cellfun(@(m) strncmp(m.content, '[context compacted:', 19), system));
[system, ok] = fit_system(system, budget.maxTokens);
if ~ok
    output = {};
    return;
end
keep = budget.keepRecent;
if keep <= 0, keep = 4; end
start = max(numel(rest) - keep, 0);
start = align_start(rest, start);
marker = struct('role', 'system', 'content', ...
    sprintf('[context compacted: %d older messages omitted]', start));
kept = rest(start + 1:end);
prefix = system;
if start > 0, prefix{end + 1} = marker; end
output = [prefix kept];
[output, ok] = shrink(output, kept, system, marker, start, budget.maxTokens);
end

function [result, ok] = fit_system(system, max_tokens)
if isempty(system)
    result = {};
    ok = true;
    return;
end
if praxo.estimate_tokens(system) <= max_tokens
    result = system;
    ok = true;
    return;
end
first = system{1};
first.content = praxo.truncate_to_tokens(first.content, max_tokens - 4);
result = [{first} system(2:end)];
ok = praxo.estimate_tokens(result) <= max_tokens;
end

function start = align_start(rest, start)
while start > 0 && strcmp(rest{start}.role, 'tool')
    start = start - 1;
end
end

function [output, ok] = shrink(output, kept, system, marker, start, max_tokens)
while praxo.estimate_tokens(output) > max_tokens && numel(kept) > 1
    if strcmp(kept{2}.role, 'tool')
        ok = false;
        return;
    end
    kept = kept(2:end);
    output = system;
    if start > 0, output{end + 1} = marker; end
    output = [output kept];
end
ok = praxo.estimate_tokens(output) <= max_tokens;
end
