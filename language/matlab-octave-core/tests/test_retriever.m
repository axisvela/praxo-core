function test_retriever()
document = praxo.document('doc-1', 'content', struct('source', 'unit'), 0.5);
assert(strcmp(document.id, 'doc-1'));
assert(strcmp(document.content, 'content'));
assert(strcmp(document.metadata.source, 'unit'));
assert(document.score == 0.5);

calls = 0;
seen_query = '';
seen_limit = -1;
    function documents = capture(query, limit)
        calls = calls + 1;
        seen_query = query;
        seen_limit = limit;
        documents = {praxo.document('doc-1', sprintf('%s:%d', query, limit), ...
            struct('source', 'unit'), 0.5)};
    end
documents = praxo.retrieve_documents(@capture, 'hello', 3);
assert(numel(documents) == 1);
assert(strcmp(documents{1}.id, 'doc-1'));
assert(strcmp(documents{1}.content, 'hello:3'));
assert(strcmp(documents{1}.metadata.source, 'unit'));
assert(documents{1}.score == 0.5);
assert(calls == 1);
assert(strcmp(seen_query, 'hello'));
assert(seen_limit == 3);

wire = praxo.document_wire(document);
assert(strcmp(wire.kind, 'object'));

wrapper = praxo.func_retriever(@capture);
wrapped = praxo.retrieve_documents(wrapper, 'hello', 2);
assert(strcmp(wrapped{1}.content, 'hello:2'));
retrieved = praxo.retriever_retrieve(wrapper, 'hello', 1);
assert(strcmp(retrieved{1}.content, 'hello:1'));

calls = 0;
caught = false;
try
    praxo.retrieve_documents(@capture, 'hello', -1);
catch err
    caught = true;
    assert(~isempty(strfind(err.message, 'RETRIEVER_INVALID')));
end
assert(caught);
assert(calls == 0);

caught = false;
try
    praxo.retrieve_documents([], 'hello', 1);
catch err
    caught = true;
    assert(~isempty(strfind(err.message, 'RETRIEVER_INVALID')));
end
assert(caught);

empty = praxo.retrieve_documents(@(query, limit) cell(1, 0), 'hello', 0);
assert(isempty(empty));
disp('test_retriever passed');
end
