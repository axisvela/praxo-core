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
01 px-user-data pic x(4096).
01 capture redefines px-user-data.
   05 filler pic x(3060).
   05 capture-url pic x(512).
   05 capture-payload pic x(512).
01 expected pic x(2048).
01 expected-length binary-long.
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
linkage section.
copy "provider-call.cpy".
01 px-user-data pic x(4096).
01 px-status pic x(64).
procedure division using px-provider-call px-user-data px-status.
    move spaces to px-status
    move px-provider-url to px-user-data(3061:512)
    move px-provider-payload to px-user-data(3573:512)
    move '{"choices":[{"message":{"content":"hello","tool_calls":[{"id":"c1","function":{"name":"echo","arguments":"{\"x\":1}"}}]}}],"usage":{"prompt_tokens":3,"completion_tokens":2}}'
        to fake-json
    move fake-json to px-provider-response
    compute px-provider-response-length = function length(
        function trim(fake-json))
    move 200 to px-provider-status-code
    goback.
end program fake-provider-transport.
