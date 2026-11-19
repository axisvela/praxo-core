       >>source format free
identification division.
program-id. openai-tests recursive.
environment division.
configuration section.
repository. function all intrinsic.
data division.
working-storage section.
01 px-session.
   copy "history.cpy".
copy "callbacks.cpy".
copy "provider-options.cpy".
copy "sse.cpy".
copy "openai-delta.cpy".
01 px-user-data pic x(4096).
01 capture redefines px-user-data.
   05 filler pic x(3060).
   05 capture-url pic x(512).
   05 capture-payload pic x(512).
01 expected pic x(2048).
01 expected-length binary-long.
01 fake-stream-found binary-long.
procedure division.
    initialize px-session px-response px-user-data
    move 2 to px-message-count
    move "system" to px-role(1)
    move "sys" to px-content(1)
    move 3 to px-content-length(1)
    move "user" to px-role(2)
    move "hi" to px-content(2)
    move 2 to px-content-length(2)
    move "fake-provider-transport" to px-provider-transport-program
    move "http://provider.test/v1" to px-provider-base-url
    move "test-model" to px-provider-model
    move "secret" to px-provider-api-key
    move 6 to px-provider-api-key-length
    move 32 to px-provider-max-tokens
    move px-provider-options to px-user-data
    call "praxo-openai" using px-session px-response
        px-user-data px-status
    if px-status not = spaces
        display "openai failed: " px-status
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
    move function trim(capture-url) to expected
    compute expected-length = function length(function trim(capture-url))
    if capture-url(1:expected-length) not =
        "http://provider.test/v1/chat/completions"
        display "unexpected url: " capture-url(1:expected-length)
        stop run returning 1
    end-if
    if function trim(capture-payload) = spaces
        display "empty payload"
        stop run returning 1
    end-if

    initialize px-response px-sse-request px-sse-result
    move 1 to px-provider-stream
    move "fake-delta" to px-provider-delta-program
    move 0 to px-delta-total
    move spaces to px-delta-capture
    move px-provider-options to px-user-data
    call "praxo-openai" using px-session px-response
        px-user-data px-status
    if px-status not = spaces
        display "openai stream failed: " px-status
        stop run returning 1
    end-if
    if px-answer(1:px-answer-length) not = "hello"
        display "unexpected stream answer: "
            px-answer(1:px-answer-length)
        stop run returning 1
    end-if
    if px-input-tokens not = 4 or px-output-tokens not = 2
        display "unexpected stream usage: " px-input-tokens " "
            px-output-tokens
        stop run returning 1
    end-if
    if px-call-count not = 1 or px-call-name(1) not = "echo"
        display "unexpected stream calls"
        stop run returning 1
    end-if
    if px-call-input(1)(1:px-call-input-length(1)) not = '{"text":"hi"}'
        display "unexpected stream arguments: "
            px-call-input(1)(1:px-call-input-length(1))
        stop run returning 1
    end-if
    if px-delta-capture(1:px-delta-total) not = "hello"
        display "unexpected stream deltas: "
            px-delta-capture(1:px-delta-total)
        stop run returning 1
    end-if
    display "OpenAI adapter tests passed"
    stop run.
end program openai-tests.

identification division.
program-id. fake-provider-transport recursive.
environment division.
configuration section.
repository. function all intrinsic.
data division.
working-storage section.
01 fake-json pic x(8192).
01 fake-stream-found binary-long.
linkage section.
copy "provider-call.cpy".
01 px-user-data pic x(4096).
01 px-status pic x(64).
procedure division using px-provider-call px-user-data px-status.
    move spaces to px-status
    move px-provider-url to px-user-data(3061:512)
    move px-provider-payload to px-user-data(3573:512)
    move 0 to fake-stream-found
    inspect px-provider-payload tallying fake-stream-found
        for all '"stream":true'
    if fake-stream-found > 0
        string
            'data: {"choices":[{"delta":{"content":"he"}}]}'
                x"0a" x"0a"
            'data: {"choices":[{"delta":{"content":"llo"}}]}'
                x"0a" x"0a"
            'data: {"choices":[{"delta":{"tool_calls":[{"index":0,'
            '"id":"call-1","function":{"name":"ec",'
            '"arguments":"{\"text\":"}}]}}]}' x"0a" x"0a"
            'data: {"choices":[{"delta":{"tool_calls":[{"index":0,'
            '"function":{"name":"ho","arguments":"\"hi\"}"}}]}}],'
            '"usage":{"prompt_tokens":4,"completion_tokens":2}}'
                x"0a" x"0a"
            'data: {"choices":[{"delta":{},"finish_reason":"tool_calls"}]}'
                x"0a" x"0a"
            'data: [DONE]' x"0a"
            into fake-json
        end-string
    else
        move '{"choices":[{"message":{"content":"hello","tool_calls":[{"id":"c1","function":{"name":"echo","arguments":"{\"x\":1}"}}]}}],"usage":{"prompt_tokens":3,"completion_tokens":2}}'
            to fake-json
    end-if
    move fake-json to px-provider-response
    compute px-provider-response-length = function length(
        function trim(fake-json))
    move 200 to px-provider-status-code
    goback.
end program fake-provider-transport.

identification division.
program-id. fake-delta recursive.
environment division.
configuration section.
repository. function all intrinsic.
data division.
working-storage section.
copy "openai-delta.cpy".
linkage section.
01 px-sse-delta-call.
   05 px-sse-delta-text pic x(2048).
   05 px-sse-delta-length binary-long.
01 px-user-data pic x(4096).
01 px-status pic x(64).
procedure division using px-sse-delta-call px-user-data px-status.
    move spaces to px-status
    if px-sse-delta-length > 0
        and px-delta-total + px-sse-delta-length <= 2048
        move px-sse-delta-text(1:px-sse-delta-length)
            to px-delta-capture(
                px-delta-total + 1:px-sse-delta-length)
        add px-sse-delta-length to px-delta-total
    end-if
    goback.
end program fake-delta.
