function out = strip_tool_call_markup(content)
if ~ischar(content) || (~isrow(content) && ~isempty(content))
    error('praxo:toolcall', 'Content must be a character row vector');
end
if numel(content) > 262144
    error('praxo:toolcall', 'Content exceeds capacity');
end
patterns = {'(?s)<tool_call\s+name="[^"]+"\s*>.*?(?:</tool_call>|$)', ...
    '(?s)<[a-zA-Z][\w-]*(?:\.[\w-]+)+>\s*\{.*?(?:</[a-zA-Z][\w.-]*>|$)'};
out = content;
for i = 1:numel(patterns)
    out = regexprep(out, patterns{i}, '');
end
out = regexprep(out, '\n{3,}', sprintf('\n\n'));
out = strtrim(out);
end
