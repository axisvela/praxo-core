       >>source format free
identification division.
program-id. anthropic-tests recursive.
environment division.
configuration section.
repository. function all intrinsic.
data division.
working-storage section.
01 px-session.
   copy "history.cpy".
copy "callbacks.cpy".
copy "anthropic-options.cpy".
01 px-user-data pic x(4096).
01 capture redefines px-user-data.
   05 filler pic x(3200).
   05 capture-url pic x(512).
   05 capture-body pic x(384).
01 ws-haystack pic x(2048).
01 ws-haystack-length binary-long.
01 ws-needle pic x(128).
01 ws-needle-length binary-long.
01 ws-scan-index binary-long.
01 ws-found-pos binary-long.
procedure division.
    initialize px-session px-response px-anthropic-options px-user-data
    move 3 to px-message-count
    move "system" to px-role(1)
    move "sys" to px-content(1)
    move 3 to px-content-length(1)
    move "user" to px-role(2)
    move "hi" to px-content(2)
    move 2 to px-content-length(2)
    move "assistant" to px-role(3)
    move "hello" to px-content(3)
    move 5 to px-content-length(3)
    move "fake-anthropic-transport" to px-anthropic-transport-program
    move "http://provider.test/v1" to px-anthropic-base-url
    move "test-model" to px-anthropic-model
    move "secret" to px-anthropic-api-key
    move 6 to px-anthropic-api-key-length
    move 64 to px-anthropic-max-tokens
    move '[{"name":"echo","input_schema":{"type":"object"}}]'
        to px-anthropic-tools
    move 50 to px-anthropic-tools-length
    move "auto" to px-anthropic-tool-choice
    move 4 to px-anthropic-tool-choice-length
    move px-anthropic-options to px-user-data
    move "S" to px-user-data(4000:1)
    call "praxo-anthropic" using px-anthropic-options px-session
        px-response px-user-data px-status
    if px-status not = spaces
        display "anthropic failed: " px-status
        stop run returning 1
    end-if
    if px-answer(1:px-answer-length) not = "hello"
        display "unexpected answer: " px-answer(1:px-answer-length)
        stop run returning 1
    end-if
    if px-input-tokens not = 3 or px-output-tokens not = 2
        display "unexpected usage: " px-input-tokens " "
            px-output-tokens
        stop run returning 1
    end-if
    if px-call-count not = 1
        display "unexpected call count: " px-call-count
        stop run returning 1
    end-if
    if px-call-name(1) not = "echo"
        display "unexpected call name: " px-call-name(1)
        stop run returning 1
    end-if
    move px-call-input(1) to ws-haystack
    move px-call-input-length(1) to ws-haystack-length
    move '"x":1' to ws-needle
    move 5 to ws-needle-length
    perform require-haystack
    move capture-url to ws-haystack
    move 512 to ws-haystack-length
    move "/v1/messages" to ws-needle
    move 12 to ws-needle-length
    perform require-haystack
    move capture-body to ws-haystack
    move 384 to ws-haystack-length
    move '"system":"sys"' to ws-needle
    move 14 to ws-needle-length
    perform require-haystack
    move '"max_tokens":64' to ws-needle
    move 15 to ws-needle-length
    perform require-haystack
    move '"tools":' to ws-needle
    move 8 to ws-needle-length
    perform require-haystack
    move '"tool_choice":{"type":"auto"}' to ws-needle
    move 29 to ws-needle-length
    perform require-haystack
    move "F" to px-user-data(4000:1)
    call "praxo-anthropic" using px-anthropic-options px-session
        px-response px-user-data px-status
    if px-status not = "PROVIDER_HTTP"
        display "expected PROVIDER_HTTP, got: " px-status
        stop run returning 1
    end-if
    move "J" to px-user-data(4000:1)
    call "praxo-anthropic" using px-anthropic-options px-session
        px-response px-user-data px-status
    if px-status not = "PROVIDER_JSON"
        display "expected PROVIDER_JSON, got: " px-status
        stop run returning 1
    end-if
    display "Anthropic adapter tests passed"
    stop run.
scan-haystack.
    move 0 to ws-found-pos
    if ws-needle-length < 1 or ws-needle-length > ws-haystack-length
        goback
    end-if
    perform varying ws-scan-index from 1 by 1
        until ws-scan-index > ws-haystack-length - ws-needle-length + 1
        if ws-haystack(ws-scan-index:ws-needle-length)
            = ws-needle(1:ws-needle-length)
            move ws-scan-index to ws-found-pos
            exit perform
        end-if
    end-perform.
require-haystack.
    perform scan-haystack
    if ws-found-pos = 0
        display "missing text: " ws-needle(1:ws-needle-length)
        stop run returning 1
    end-if.
end program anthropic-tests.

identification division.
program-id. fake-anthropic-transport recursive.
environment division.
configuration section.
repository. function all intrinsic.
data division.
working-storage section.
01 ws-mode pic x.
01 fake-json pic x(8192).
linkage section.
copy "anthropic-call.cpy".
01 px-user-data pic x(4096).
01 px-status pic x(64).
procedure division using px-anthropic-call px-user-data px-status.
    move spaces to px-status
    move px-user-data(4000:1) to ws-mode
    move px-anthropic-url to px-user-data(3201:512)
    move px-anthropic-body to px-user-data(3713:384)
    if ws-mode = "F"
        move 500 to px-anthropic-status-code
        goback
    end-if
    if ws-mode = "J"
        move 200 to px-anthropic-status-code
        move "not json" to px-anthropic-response
        move 8 to px-anthropic-response-length
        goback
    end-if
    move '{"content":[{"type":"text","text":"hello"},{"type":"tool_use","id":"tu1","name":"echo","input":{"x":1}}],"usage":{"input_tokens":3,"output_tokens":2}}'
        to fake-json
    move fake-json to px-anthropic-response
    compute px-anthropic-response-length = function length(
        function trim(fake-json))
    move 200 to px-anthropic-status-code
    goback.
end program fake-anthropic-transport.
