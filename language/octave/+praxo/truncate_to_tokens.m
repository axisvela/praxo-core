function value = truncate_to_tokens(value, tokens)
if tokens <= 0
    value = '';
    return;
end
limit = tokens * 4;
if numel(value) <= limit
    return;
end
if limit <= 16
    value = value(1:limit);
else
    value = [value(1:limit - 16) sprintf('\n[truncated]')];
end
end
