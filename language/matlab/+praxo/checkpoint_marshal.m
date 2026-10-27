function [data, code] = checkpoint_marshal(allow, kind, value)
if any(strcmp(allow.registered, kind))
    data = praxo.encode_json(praxo.json_make_object({ ...
        'type', praxo.json_make_string(kind); ...
        'data', value}));
    code = '';
else
    data = '';
    code = 'CHECKPOINT_TYPE_NOT_ALLOWED';
end
end
