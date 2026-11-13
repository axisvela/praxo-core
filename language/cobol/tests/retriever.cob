       >>source format free
identification division.
program-id. retriever-tests recursive.
environment division.
configuration section.
repository. function all intrinsic.
data division.
working-storage section.
copy "retriever.cpy".
01 px-user-data pic x(4096).
01 px-status pic x(64).
procedure division.
    initialize px-retriever-request px-retriever-result px-user-data
    move "hello" to px-ret-query
    move 5 to px-ret-query-length
    move 2 to px-ret-limit
    move "fake-retriever" to px-ret-callback-program
    move "S" to px-user-data(1:1)
    call "praxo-retriever" using px-retriever-request
        px-retriever-result px-user-data px-status
    if px-status not = spaces
        display "retriever failed: " px-status
        stop run returning 1
    end-if
    if px-ret-count not = 2
        display "unexpected document count: " px-ret-count
        stop run returning 1
    end-if
    if function trim(px-ret-doc-id(1)) not = "doc1"
        display "unexpected document id: " px-ret-doc-id(1)
        stop run returning 1
    end-if
    if px-ret-doc-content-length(1) not = 5
        display "unexpected content length: "
            px-ret-doc-content-length(1)
        stop run returning 1
    end-if
    if px-ret-doc-score-has(1) not = 1
        display "missing document score"
        stop run returning 1
    end-if
    move -1 to px-ret-limit
    call "praxo-retriever" using px-retriever-request
        px-retriever-result px-user-data px-status
    if px-status not = "RETRIEVER_INVALID"
        display "expected RETRIEVER_INVALID, got: " px-status
        stop run returning 1
    end-if
    move 2 to px-ret-limit
    move spaces to px-ret-callback-program
    call "praxo-retriever" using px-retriever-request
        px-retriever-result px-user-data px-status
    if px-status not = "RETRIEVER_INVALID"
        display "expected missing callback error, got: " px-status
        stop run returning 1
    end-if
    move "fake-retriever" to px-ret-callback-program
    move "E" to px-user-data(1:1)
    call "praxo-retriever" using px-retriever-request
        px-retriever-result px-user-data px-status
    if px-status not = "RETRIEVER_CALLBACK"
        display "expected callback error, got: " px-status
        stop run returning 1
    end-if
    if px-ret-count not = 0
        display "callback error left documents"
        stop run returning 1
    end-if
    display "Retriever tests passed"
    stop run.
end program retriever-tests.

identification division.
program-id. fake-retriever recursive.
environment division.
configuration section.
repository. function all intrinsic.
data division.
linkage section.
copy "retriever.cpy".
01 px-user-data pic x(4096).
01 px-status pic x(64).
procedure division using px-retriever-request px-retriever-result
    px-user-data px-status.
    move spaces to px-status
    if px-user-data(1:1) = "E"
        move "RETRIEVER_CALLBACK" to px-status
        goback
    end-if
    if px-ret-limit not = 2
        move "RETRIEVER_BAD_LIMIT" to px-status
        goback
    end-if
    if px-ret-query-length not = 5
        or px-ret-query(1:5) not = "hello"
        move "RETRIEVER_BAD_QUERY" to px-status
        goback
    end-if
    move 2 to px-ret-count
    move "doc1" to px-ret-doc-id(1)
    move 4 to px-ret-doc-id-length(1)
    move "first" to px-ret-doc-content(1)
    move 5 to px-ret-doc-content-length(1)
    move 1 to px-ret-doc-score-has(1)
    move 0.5 to px-ret-doc-score(1)
    move "doc2" to px-ret-doc-id(2)
    move 4 to px-ret-doc-id-length(2)
    move "second" to px-ret-doc-content(2)
    move 6 to px-ret-doc-content-length(2)
    move 0 to px-ret-doc-score-has(2)
    goback.
end program fake-retriever.
