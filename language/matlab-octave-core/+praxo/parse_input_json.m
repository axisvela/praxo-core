function value = parse_input_json(raw)
value = [];
try
    node = praxo.parse_json(strtrim(raw));
    if strcmp(node.kind, 'object')
        value = node;
    end
catch
    value = [];
end
end
