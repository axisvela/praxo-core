       >>source format free
identification division.
program-id. session-checkpoint-example.
environment division.
configuration section.
repository. function all intrinsic.
data division.
working-storage section.
copy "api.cpy".
copy "checkpoint.cpy".
copy "json.cpy".
01 ws-count pic zzz9.
01 ws-index binary-long.
01 ws-next binary-long.
01 ws-restored-count binary-long.
01 ws-last pic x(2048).
01 ws-last-length binary-long.
procedure division.
    initialize px-options px-session px-prompt px-result
    initialize px-checkpoint-request px-checkpoint-result
    move "turn-model" to px-model-program
    move 4 to px-max-steps
    move "second" to px-prompt-text
    move 6 to px-prompt-length

    move 2 to px-message-count
    move "user" to px-role(1)
    move "first" to px-content(1)
    move 5 to px-content-length(1)
    move "assistant" to px-role(2)
    move "ack" to px-content(2)
    move 3 to px-content-length(2)

    call "praxo-run" using px-options px-session px-prompt
        px-result px-user-data
    if px-result-error not = spaces or px-result-output not = "turn 3"
        display "second turn failed: " function trim(px-result-error)
        stop run returning 1
    end-if

    move 3 to px-message-count
    move "user" to px-role(3)
    move "second" to px-content(3)
    move 6 to px-content-length(3)
    move 4 to px-message-count
    move "assistant" to px-role(4)
    move px-result-output(1:px-result-length) to px-content(4)
    move px-result-length to px-content-length(4)

    move "register" to px-ck-op
    move "session" to px-ck-type
    move 7 to px-ck-type-length
    call "praxo-checkpoint" using px-checkpoint-request px-checkpoint-result
    if px-ck-error not = spaces
        display "checkpoint register failed: " function trim(px-ck-error)
        stop run returning 1
    end-if

    move 4 to ws-count
    string '{"messages":' function trim(ws-count)
        ',"last":"' px-result-output(1:px-result-length) '"}'
        into px-ck-value
    compute px-ck-value-length = function length(
        function trim(px-ck-value trailing))
    move "marshal" to px-ck-op
    call "praxo-checkpoint" using px-checkpoint-request px-checkpoint-result
    if px-ck-error not = spaces
        display "checkpoint marshal failed: " function trim(px-ck-error)
        stop run returning 1
    end-if

    move px-ck-output(1:px-ck-output-length) to px-ck-value
    move px-ck-output-length to px-ck-value-length
    move "unmarshal" to px-ck-op
    call "praxo-checkpoint" using px-checkpoint-request px-checkpoint-result
    if px-ck-error not = spaces
        display "checkpoint unmarshal failed: " function trim(px-ck-error)
        stop run returning 1
    end-if

    move px-ck-output(1:px-ck-output-length) to px-json-text
    move px-ck-output-length to px-json-length
    call "praxo-json-parse" using px-json-input px-json-document
        px-json-error
    if px-json-error not = spaces
        display "payload parse failed: " function trim(px-json-error)
        stop run returning 1
    end-if

    move 0 to ws-restored-count
    move spaces to ws-last
    perform varying ws-index from 1 by 1
        until ws-index > px-json-count
        if px-json-kind(ws-index) = 'K'
            compute ws-next = ws-index + 1
            if function trim(px-json-value(ws-index)) = "messages"
                move function numval(px-json-value(ws-next))
                    to ws-restored-count
            end-if
            if function trim(px-json-value(ws-index)) = "last"
                move px-json-value(ws-next) to ws-last
                move px-json-value-length(ws-next) to ws-last-length
            end-if
        end-if
    end-perform
    if ws-restored-count not = 4 or ws-last(1:6) not = "turn 3"
        display "payload recovery failed"
        stop run returning 1
    end-if

    initialize px-session px-result
    move ws-restored-count to px-message-count
    move "user" to px-role(1)
    move "first" to px-content(1)
    move 5 to px-content-length(1)
    move "assistant" to px-role(2)
    move "ack" to px-content(2)
    move 3 to px-content-length(2)
    move "user" to px-role(3)
    move "second" to px-content(3)
    move 6 to px-content-length(3)
    move "assistant" to px-role(4)
    move ws-last(1:ws-last-length) to px-content(4)
    move ws-last-length to px-content-length(4)

    move "third" to px-prompt-text
    move 5 to px-prompt-length
    call "praxo-run" using px-options px-session px-prompt
        px-result px-user-data
    if px-result-error not = spaces or px-result-output not = "turn 5"
        display "third turn failed: " function trim(px-result-error)
        stop run returning 1
    end-if

    move ws-restored-count to ws-count
    display "restored messages: " function trim(ws-count)
    display "output: " px-result-output(1:px-result-length)

    stop run.
end program session-checkpoint-example.

identification division.
program-id. turn-model recursive.
data division.
working-storage section.
01 ws-count pic zzz9.
01 ws-text pic x(32).
linkage section.
copy "api.cpy".
procedure division using px-session px-response px-user-data px-status.
    move px-message-count to ws-count
    initialize ws-text
    string "turn " function trim(ws-count) into ws-text
    move ws-text to px-answer
    compute px-answer-length = function length(
        function trim(px-answer trailing))
    move 0 to px-call-count
    goback.
end program turn-model.
