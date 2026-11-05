function tokens = estimate_tokens(messages)
tokens = 0;
for i = 1:numel(messages)
    message = messages{i};
    tool_id = '';
    if isfield(message, 'toolId'), tool_id = message.toolId; end
    tokens = tokens + 4 + floor(numel(message.content) / 4) + floor(numel(tool_id) / 4);
    if isfield(message, 'contentBlocks')
        for j = 1:numel(message.contentBlocks)
            text = '';
            if isfield(message.contentBlocks{j}, 'text'), text = message.contentBlocks{j}.text; end
            tokens = tokens + 4 + floor(numel(text) / 4);
        end
    end
    if isfield(message, 'toolCalls')
        for j = 1:numel(message.toolCalls)
            call = message.toolCalls{j};
            tokens = tokens + 4 + floor(numel(call.name) / 4) + ...
                floor(numel(praxo.encode_json(call.arguments)) / 4);
        end
    end
end
end
