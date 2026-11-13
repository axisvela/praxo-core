       >>source format free
identification division.
program-id. praxo-retriever recursive.
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
    initialize px-retriever-result
    move spaces to px-status
    if px-ret-limit < 0
        move "RETRIEVER_INVALID" to px-status
        goback
    end-if
    if px-ret-callback-program = spaces
        move "RETRIEVER_INVALID" to px-status
        goback
    end-if
    call px-ret-callback-program using px-retriever-request
        px-retriever-result px-user-data px-status
    if px-status not = spaces
        move 0 to px-ret-count
        goback
    end-if
    if px-ret-count < 0 or px-ret-count > 32
        move 0 to px-ret-count
        move "RETRIEVER_INVALID" to px-status
    end-if
    goback.
end program praxo-retriever.
