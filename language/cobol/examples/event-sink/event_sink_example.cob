       >>source format free
identification division.
program-id. event-sink-example.
environment division.
configuration section.
repository. function all intrinsic.
data division.
working-storage section.
copy "event.cpy".
procedure division.
    initialize px-event-request px-event-result
    move "multi" to px-evt-op
    move 3 to px-evt-count
    move "run.started" to px-evt-events(1)
    move "tool.call" to px-evt-events(2)
    move "run.completed" to px-evt-events(3)
    move 2 to px-evt-sink-count
    call "praxo-event" using px-event-request px-event-result
    if px-evt-error not = spaces
        display "multi failed: " px-evt-error
        stop run returning 1
    end-if
    if px-evt-sink-total not = 2
        or px-evt-sink-type-count(1) not = 3
        or px-evt-sink-type-count(2) not = 3
        display "multi result mismatch"
        stop run returning 1
    end-if

    initialize px-event-request px-event-result
    move "filter" to px-evt-op
    move 1 to px-evt-predicate-count
    move "tool.call" to px-evt-predicates(1)
    move 3 to px-evt-count
    move "run.started" to px-evt-events(1)
    move "tool.call" to px-evt-events(2)
    move "run.completed" to px-evt-events(3)
    call "praxo-event" using px-event-request px-event-result
    if px-evt-error not = spaces
        display "filter failed: " px-evt-error
        stop run returning 1
    end-if
    if px-evt-delivered-count not = 1
        or px-evt-delivered(1) not = "tool.call"
        display "filter result mismatch"
        stop run returning 1
    end-if

    display "COBOL event sink example passed"
    stop run.
