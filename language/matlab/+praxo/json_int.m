function value = json_int(node, key, fallback)
value = fallback;
[item, found] = praxo.json_field(node, key);
if found && strcmp(item.kind, 'number') && item.value == fix(item.value)
    value = item.value;
end
end
