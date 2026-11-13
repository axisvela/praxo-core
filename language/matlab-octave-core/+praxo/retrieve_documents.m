function documents = retrieve_documents(retriever, query, limit)
if isstruct(retriever) && isscalar(retriever) && isfield(retriever, 'retrieve')
    retriever = retriever.retrieve;
end
if ~isa(retriever, 'function_handle')
    error('praxo:retriever', 'RETRIEVER_INVALID: retriever: retriever is required');
end
if ~isnumeric(limit) || ~isscalar(limit) || ~isfinite(limit) || limit < 0
    error('praxo:retriever', 'RETRIEVER_INVALID: retriever: invalid limit');
end
if isa(retriever, 'function_handle')
    callback = retriever;
elseif isstruct(retriever) && isscalar(retriever) && ...
        isfield(retriever, 'retrieve') && isa(retriever.retrieve, 'function_handle')
    callback = retriever.retrieve;
else
    error('praxo:retriever', ...
        'RETRIEVER_INVALID: retriever: retriever is required');
end
if ~ischar(query)
    error('praxo:retriever', ...
        'RETRIEVER_INVALID: retriever: query must be a character vector');
end
documents = callback(query, limit);
if isempty(documents)
    documents = {};
end
if ~iscell(documents)
    error('praxo:retriever', ...
        'RETRIEVER_INVALID: retriever: retriever returned invalid documents');
end
end
