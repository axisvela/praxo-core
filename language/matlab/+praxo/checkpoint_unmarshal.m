function [value, code] = checkpoint_unmarshal(allow, data)
value = [];
code = 'CHECKPOINT_ERROR';
try
    envelope = praxo.parse_json(data);
catch
    return;
end
if ~strcmp(envelope.kind, 'object')
    return;
end
[type, found] = praxo.json_field(envelope, 'type');
if ~found || ~strcmp(type.kind, 'string') || ~any(strcmp(allow.registered, type.value))
    code = 'CHECKPOINT_TYPE_NOT_ALLOWED';
    return;
end
[value, found] = praxo.json_field(envelope, 'data');
if ~found
    value = praxo.json_make_null();
end
code = '';
end
