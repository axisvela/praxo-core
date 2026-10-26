       >>source format free
identification division.
program-id. praxo-event recursive.
environment division.
configuration section.
repository. function all intrinsic.
data division.
local-storage section.
01 event-index binary-long.
01 predicate-index binary-long.
01 sink-index binary-long.
01 matches pic 9.
linkage section.
copy "event.cpy".
procedure division using px-event-request px-event-result.
    initialize px-event-result
    if px-evt-count < 0 or > 64
        or px-evt-predicate-count < 0 or > 32
        or px-evt-sink-count < 0 or > 8
        move "INVALID_REQUEST" to px-evt-error
        goback
    end-if
    evaluate px-evt-op
        when "filter" perform filter-events
        when "multi" perform multicast
        when other move "INVALID_REQUEST" to px-evt-error
    end-evaluate
    goback.
filter-events.
    move 0 to px-evt-delivered-count
    perform varying event-index from 1 by 1
        until event-index > px-evt-count
        move 1 to matches
        if px-evt-predicate-count > 0
            move 0 to matches
            perform varying predicate-index from 1 by 1
                until predicate-index > px-evt-predicate-count
                if px-evt-events(event-index)
                    = px-evt-predicates(predicate-index)
                    move 1 to matches
                end-if
            end-perform
        end-if
        if matches = 1
            add 1 to px-evt-delivered-count
            move px-evt-events(event-index)
                to px-evt-delivered(px-evt-delivered-count)
        end-if
    end-perform.
multicast.
    move px-evt-sink-count to px-evt-sink-total
    perform varying sink-index from 1 by 1
        until sink-index > px-evt-sink-count
        move px-evt-count to px-evt-sink-type-count(sink-index)
        perform varying event-index from 1 by 1
            until event-index > px-evt-count
            move px-evt-events(event-index)
                to px-evt-sink-types(sink-index, event-index)
        end-perform
    end-perform.
end program praxo-event.
