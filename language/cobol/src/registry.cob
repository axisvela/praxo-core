       >>source format free
identification division.
program-id. praxo-registry recursive.
environment division.
configuration section.
repository. function all intrinsic.
data division.
working-storage section.
01 entry-count binary-long value 0.
01 entry-index binary-long.
01 search-index binary-long.
01 found-index binary-long.
01 name-matches pic 9.
01 swap-entry.
   05 swap-name pic x(64).
   05 swap-name-length binary-long.
   05 swap-description pic x(256).
   05 swap-description-length binary-long.
   05 swap-program pic x(64).
   05 swap-program-length binary-long.
   05 swap-risk pic x(16).
   05 swap-risk-length binary-long.
01 stored-entries occurs 32 times.
   05 stored-name pic x(64).
   05 stored-name-length binary-long.
   05 stored-description pic x(256).
   05 stored-description-length binary-long.
   05 stored-program pic x(64).
   05 stored-program-length binary-long.
   05 stored-risk pic x(16).
   05 stored-risk-length binary-long.
linkage section.
copy "registry.cpy".
procedure division using px-registry-request px-registry-result.
    initialize px-registry-result
    evaluate px-reg-op
        when "register" perform register-entry
        when "get" perform get-entry
        when "list" perform list-entries
        when "clear" move 0 to entry-count
        when other move "INVALID_REQUEST" to px-reg-error
    end-evaluate
    goback.
register-entry.
    if px-reg-name-length < 0 or > 64
        or px-reg-description-length < 0 or > 256
        or px-reg-program-length < 0 or > 64
        or px-reg-risk-length < 0 or > 16
        move "INVALID_REQUEST" to px-reg-error
        exit paragraph
    end-if
    move 0 to found-index
    perform varying entry-index from 1 by 1
        until entry-index > entry-count
        perform name-match
        if name-matches = 1
            move entry-index to found-index
            exit perform
        end-if
    end-perform
    if found-index = 0
        if entry-count >= 32
            move "REGISTRY_CAPACITY" to px-reg-error
            exit paragraph
        end-if
        add 1 to entry-count
        move entry-count to found-index
    end-if
    move px-reg-name to stored-name(found-index)
    move px-reg-name-length to stored-name-length(found-index)
    move px-reg-description to stored-description(found-index)
    move px-reg-description-length to stored-description-length(found-index)
    move px-reg-program to stored-program(found-index)
    move px-reg-program-length to stored-program-length(found-index)
    move px-reg-risk to stored-risk(found-index)
    move px-reg-risk-length to stored-risk-length(found-index).
get-entry.
    if px-reg-name-length < 0 or > 64
        move "INVALID_REQUEST" to px-reg-error
        exit paragraph
    end-if
    move 0 to found-index
    perform varying entry-index from 1 by 1
        until entry-index > entry-count
        perform name-match
        if name-matches = 1
            move entry-index to found-index
            exit perform
        end-if
    end-perform
    if found-index = 0
        move "TOOL_NOT_FOUND" to px-reg-error
        exit paragraph
    end-if
    move 1 to px-reg-count
    move stored-name(found-index) to px-reg-entry-name(1)
    move stored-name-length(found-index) to px-reg-entry-name-length(1)
    move stored-description(found-index) to px-reg-entry-description(1)
    move stored-description-length(found-index)
        to px-reg-entry-description-length(1)
    move stored-program(found-index) to px-reg-entry-program(1)
    move stored-program-length(found-index)
        to px-reg-entry-program-length(1)
    move stored-risk(found-index) to px-reg-entry-risk(1)
    move stored-risk-length(found-index) to px-reg-entry-risk-length(1).
list-entries.
    move entry-count to px-reg-count
    perform varying entry-index from 1 by 1
        until entry-index > entry-count
        move stored-name(entry-index) to px-reg-entry-name(entry-index)
        move stored-name-length(entry-index)
            to px-reg-entry-name-length(entry-index)
        move stored-description(entry-index)
            to px-reg-entry-description(entry-index)
        move stored-description-length(entry-index)
            to px-reg-entry-description-length(entry-index)
        move stored-program(entry-index) to px-reg-entry-program(entry-index)
        move stored-program-length(entry-index)
            to px-reg-entry-program-length(entry-index)
        move stored-risk(entry-index) to px-reg-entry-risk(entry-index)
        move stored-risk-length(entry-index)
            to px-reg-entry-risk-length(entry-index)
    end-perform
    perform varying entry-index from 2 by 1
        until entry-index > px-reg-count
        move entry-index to search-index
        perform until search-index <= 1
            if px-reg-entry-name(search-index - 1)
                <= px-reg-entry-name(search-index)
                exit perform
            end-if
            move px-reg-entry-name(search-index - 1) to swap-name
            move px-reg-entry-name-length(search-index - 1)
                to swap-name-length
            move px-reg-entry-description(search-index - 1)
                to swap-description
            move px-reg-entry-description-length(search-index - 1)
                to swap-description-length
            move px-reg-entry-program(search-index - 1)
                to swap-program
            move px-reg-entry-program-length(search-index - 1)
                to swap-program-length
            move px-reg-entry-risk(search-index - 1) to swap-risk
            move px-reg-entry-risk-length(search-index - 1)
                to swap-risk-length
            move px-reg-entry-name(search-index)
                to px-reg-entry-name(search-index - 1)
            move px-reg-entry-name-length(search-index)
                to px-reg-entry-name-length(search-index - 1)
            move px-reg-entry-description(search-index)
                to px-reg-entry-description(search-index - 1)
            move px-reg-entry-description-length(search-index)
                to px-reg-entry-description-length(search-index - 1)
            move px-reg-entry-program(search-index)
                to px-reg-entry-program(search-index - 1)
            move px-reg-entry-program-length(search-index)
                to px-reg-entry-program-length(search-index - 1)
            move px-reg-entry-risk(search-index)
                to px-reg-entry-risk(search-index - 1)
            move px-reg-entry-risk-length(search-index)
                to px-reg-entry-risk-length(search-index - 1)
            move swap-name to px-reg-entry-name(search-index)
            move swap-name-length to px-reg-entry-name-length(search-index)
            move swap-description to px-reg-entry-description(search-index)
            move swap-description-length
                to px-reg-entry-description-length(search-index)
            move swap-program to px-reg-entry-program(search-index)
            move swap-program-length
                to px-reg-entry-program-length(search-index)
            move swap-risk to px-reg-entry-risk(search-index)
            move swap-risk-length to px-reg-entry-risk-length(search-index)
            subtract 1 from search-index
        end-perform
    end-perform.
name-match.
    move 1 to name-matches
    if stored-name-length(entry-index) not = px-reg-name-length
        move 0 to name-matches
    else
        if px-reg-name-length > 0
            if stored-name(entry-index)(1:px-reg-name-length)
                not = px-reg-name(1:px-reg-name-length)
                move 0 to name-matches
            end-if
        end-if
    end-if.
end program praxo-registry.
