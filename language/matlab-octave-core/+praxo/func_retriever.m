function retriever = func_retriever(retrieve)
if ~isa(retrieve, 'function_handle')
    error('praxo:retriever', ...
        'RETRIEVER_INVALID: retriever: retrieve must be a function');
end
retriever = struct('retrieve', retrieve);
end
