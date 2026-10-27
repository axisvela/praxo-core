function value = extract_json(text)
value = [];
value_text = strtrim(text);
if numel(value_text) >= 3 && strcmp(value_text(1:3), '```')
    value_text = regexprep(value_text, '^```[^\n]*\n', '');
    value_text = regexprep(value_text, '```\s*$', '');
    value_text = strtrim(value_text);
end
start = regexp(value_text, '[{\[]', 'once');
if isempty(start)
    return;
end
try
    value = praxo.parse_json(value_text(start:end));
catch
    value = [];
end
end
