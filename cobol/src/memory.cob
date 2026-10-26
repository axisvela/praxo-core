       >>source format free
identification division.
program-id. praxo-memory recursive.
environment division.
configuration section.
repository. function all intrinsic.
data division.
working-storage section.
01 stored-count binary-long value 0.
01 stored-records occurs 64 times.
   05 stored-session pic x(128).
   05 stored-session-length binary-long.
   05 stored-id pic x(64).
   05 stored-id-length binary-long.
   05 stored-content pic x(2048).
   05 stored-content-length binary-long.
   05 stored-created pic x(40).
01 search-count binary-long.
01 search-index binary-long.
01 sort-index binary-long.
01 lower-query pic x(2048).
01 lower-content pic x(2048).
01 query-matches binary-long.
01 session-matches pic 9.
01 swap-record.
   05 swap-id pic x(64).
   05 swap-id-length binary-long.
   05 swap-content pic x(2048).
   05 swap-content-length binary-long.
   05 swap-created pic x(40).
linkage section.
copy "memory.cpy".
procedure division using px-memory-request px-memory-result.
    initialize px-memory-result
    evaluate px-mem-op
        when "put" perform put-record
        when "search" perform search-records
        when "clear" move 0 to stored-count
        when other move "INVALID_REQUEST" to px-mem-error
    end-evaluate
    goback.
put-record.
    if px-mem-session-length < 0 or > 128
        or px-mem-id-length < 0 or > 64
        or px-mem-content-length < 0 or > 2048
        move "INVALID_REQUEST" to px-mem-error
        exit paragraph
    end-if
    if stored-count >= 64
        move "MEMORY_CAPACITY" to px-mem-error
        exit paragraph
    end-if
    add 1 to stored-count
    move px-mem-session to stored-session(stored-count)
    move px-mem-session-length to stored-session-length(stored-count)
    move px-mem-id to stored-id(stored-count)
    move px-mem-id-length to stored-id-length(stored-count)
    move px-mem-content to stored-content(stored-count)
    move px-mem-content-length to stored-content-length(stored-count)
    move px-mem-created to stored-created(stored-count).
search-records.
    if px-mem-session-length < 0 or > 128
        or px-mem-query-length < 0 or > 2048
        move "INVALID_REQUEST" to px-mem-error
        exit paragraph
    end-if
    move px-mem-query to lower-query
    inspect lower-query converting
        "ABCDEFGHIJKLMNOPQRSTUVWXYZ" to "abcdefghijklmnopqrstuvwxyz"
    move 0 to search-count
    perform varying search-index from 1 by 1
        until search-index > stored-count
        move 0 to session-matches
        if stored-session-length(search-index) = px-mem-session-length
            if px-mem-session-length = 0
                move 1 to session-matches
            else
                if stored-session(search-index)(1:px-mem-session-length)
                    = px-mem-session(1:px-mem-session-length)
                    move 1 to session-matches
                end-if
            end-if
        end-if
        if session-matches = 1
            move stored-content(search-index) to lower-content
            inspect lower-content converting
                "ABCDEFGHIJKLMNOPQRSTUVWXYZ" to "abcdefghijklmnopqrstuvwxyz"
            move 0 to query-matches
            if px-mem-query-length > 0
                and stored-content-length(search-index) > 0
                inspect lower-content(
                    1:stored-content-length(search-index))
                    tallying query-matches
                    for all lower-query(1:px-mem-query-length)
            end-if
            if px-mem-query-length = 0 or query-matches > 0
                add 1 to search-count
                move stored-id(search-index) to px-mem-res-id(search-count)
                move stored-id-length(search-index)
                    to px-mem-res-id-length(search-count)
                move stored-content(search-index)
                    to px-mem-res-content(search-count)
                move stored-content-length(search-index)
                    to px-mem-res-content-length(search-count)
                move stored-created(search-index)
                    to px-mem-res-created(search-count)
            end-if
        end-if
    end-perform
    perform varying search-index from 2 by 1
        until search-index > search-count
        move search-index to sort-index
        perform until sort-index <= 1
            if px-mem-res-created(sort-index - 1)
                >= px-mem-res-created(sort-index)
                exit perform
            end-if
            move px-mem-res-id(sort-index - 1) to swap-id
            move px-mem-res-id-length(sort-index - 1)
                to swap-id-length
            move px-mem-res-content(sort-index - 1) to swap-content
            move px-mem-res-content-length(sort-index - 1)
                to swap-content-length
            move px-mem-res-created(sort-index - 1) to swap-created
            move px-mem-res-id(sort-index) to px-mem-res-id(sort-index - 1)
            move px-mem-res-id-length(sort-index)
                to px-mem-res-id-length(sort-index - 1)
            move px-mem-res-content(sort-index)
                to px-mem-res-content(sort-index - 1)
            move px-mem-res-content-length(sort-index)
                to px-mem-res-content-length(sort-index - 1)
            move px-mem-res-created(sort-index)
                to px-mem-res-created(sort-index - 1)
            move swap-id to px-mem-res-id(sort-index)
            move swap-id-length to px-mem-res-id-length(sort-index)
            move swap-content to px-mem-res-content(sort-index)
            move swap-content-length
                to px-mem-res-content-length(sort-index)
            move swap-created to px-mem-res-created(sort-index)
            subtract 1 from sort-index
        end-perform
    end-perform
    if px-mem-limit > 0 and px-mem-limit < search-count
        move px-mem-limit to px-mem-count
    else
        move search-count to px-mem-count
    end-if.
end program praxo-memory.
