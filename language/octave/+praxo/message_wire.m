function node = message_wire(message)
pairs = {'role', praxo.json_make_string(message.role)};
content = message.content;
blocks = {};
calls = {};
tool_id = '';
if isfield(message, 'contentBlocks'), blocks = message.contentBlocks; end
if isfield(message, 'toolCalls'), calls = message.toolCalls; end
if isfield(message, 'toolId'), tool_id = message.toolId; end
if ~isempty(content) || (isempty(blocks) && isempty(calls) && isempty(tool_id))
    pairs(end + 1, :) = {'content', praxo.json_make_string(content)};
end
if ~isempty(blocks)
    encoded = cell(1, numel(blocks));
    for i = 1:numel(blocks)
        block = blocks{i};
        block_pairs = {'type', praxo.json_make_string(block.blockType)};
        if isfield(block, 'text') && ~isempty(block.text)
            block_pairs(end + 1, :) = {'text', praxo.json_make_string(block.text)};
        end
        if isfield(block, 'imageUrl') && ~isempty(block.imageUrl)
            block_pairs(end + 1, :) = {'image_url', praxo.json_make_string(block.imageUrl)};
        end
        if isfield(block, 'data') && ~isempty(block.data)
            block_pairs(end + 1, :) = {'data', praxo.json_make_string(block.data)};
        end
        encoded{i} = praxo.json_make_object(block_pairs);
    end
    pairs(end + 1, :) = {'contentBlocks', praxo.json_make_array(encoded)};
end
if ~isempty(calls)
    encoded = cell(1, numel(calls));
    for i = 1:numel(calls)
        encoded{i} = praxo.json_make_object({ ...
            'id', praxo.json_make_string(calls{i}.id); ...
            'name', praxo.json_make_string(calls{i}.name); ...
            'arguments', calls{i}.arguments});
    end
    pairs(end + 1, :) = {'toolCalls', praxo.json_make_array(encoded)};
end
if ~isempty(tool_id)
    pairs(end + 1, :) = {'toolId', praxo.json_make_string(tool_id)};
end
node = praxo.json_make_object(pairs);
end
