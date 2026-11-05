function allow = checkpoint_register(allow, kind)
if isempty(kind)
    error('praxo:checkpoint', 'CHECKPOINT_ERROR');
end
if ~any(strcmp(allow.registered, kind))
    allow.registered{end + 1} = kind;
end
end
