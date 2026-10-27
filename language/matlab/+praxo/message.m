function value = message(role, content)
value = struct('role', role, 'content', content, 'contentBlocks', {{}}, ...
    'toolCalls', {{}}, 'toolId', '');
end
