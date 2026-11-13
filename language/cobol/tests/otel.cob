       >>source format free
identification division.
program-id. otel-tests recursive.
environment division.
configuration section.
repository. function all intrinsic.
data division.
working-storage section.
copy "otel.cpy".
copy "otel-event.cpy".
01 px-user-data pic x(4096).
01 px-status pic x(64).
01 ws-body-copy pic x(16384).
01 ws-body-length binary-long.
01 ws-start binary-long.
01 ws-length binary-long.
01 ws-error binary-long.
01 ws-needle pic x(128).
01 ws-needle-length binary-long.
01 ws-scan-index binary-long.
01 ws-scan-from binary-long.
01 ws-found-pos binary-long.
procedure division.
    initialize px-otel-options px-otel-result px-otel-event
        px-user-data
    move "fake-otel-transport" to px-otel-transport-program
    move "http://otel.test/v1/traces" to px-otel-endpoint
    move "test-service" to px-otel-service-name
    move "tool.call" to px-otel-event-type
    move "s1" to px-otel-event-session-id
    move "run-123" to px-otel-event-run-id
    move 1794294000000000000 to px-otel-event-nanos
    move '{"token":"secret","count":2}' to px-otel-event-data
    move 28 to px-otel-event-data-length
    move "S" to px-user-data(1:1)
    move 0 to px-otel-allowed-key-count
    call "praxo-otel" using px-otel-options px-otel-result
        px-otel-event px-user-data px-status
    if px-status not = spaces
        display "otel failed: " px-status
        stop run returning 1
    end-if
    if px-otel-output-length < 1
        display "empty otel body"
        stop run returning 1
    end-if
    move px-otel-output(1:px-otel-output-length) to ws-body-copy
    move px-otel-output-length to ws-body-length
    move "secret" to ws-needle
    move 6 to ws-needle-length
    move 1 to ws-scan-from
    perform scan-body
    if ws-found-pos not = 0
        display "otel leaked data without allowlist"
        stop run returning 1
    end-if
    perform check-trace-id
    perform check-span-id
    move '"praxo.event.data.token"' to ws-needle
    move 24 to ws-needle-length
    move 1 to ws-scan-from
    perform scan-body
    if ws-found-pos not = 0
        display "unexpected data attribute before allowlist"
        stop run returning 1
    end-if
    call "praxo-otel" using px-otel-options px-otel-result
        px-otel-event px-user-data px-status
    if px-status not = spaces
        display "otel second call failed: " px-status
        stop run returning 1
    end-if
    if px-otel-output-length not = ws-body-length
        display "otel ids are not deterministic"
        stop run returning 1
    end-if
    if px-otel-output(1:px-otel-output-length) not =
        ws-body-copy(1:ws-body-length)
        display "otel body is not deterministic"
        stop run returning 1
    end-if
    move 1 to px-otel-allowed-key-count
    move "token" to px-otel-allowed-keys(1)
    call "praxo-otel" using px-otel-options px-otel-result
        px-otel-event px-user-data px-status
    if px-status not = spaces
        display "otel allowlist call failed: " px-status
        stop run returning 1
    end-if
    move px-otel-output(1:px-otel-output-length) to ws-body-copy
    move px-otel-output-length to ws-body-length
    move '"praxo.event.data.token"' to ws-needle
    move 24 to ws-needle-length
    perform require-body
    move "secret" to ws-needle
    move 6 to ws-needle-length
    perform require-body
    move '"praxo.event.data.count"' to ws-needle
    move 24 to ws-needle-length
    move 1 to ws-scan-from
    perform scan-body
    if ws-found-pos not = 0
        display "otel emitted non-allowlisted key"
        stop run returning 1
    end-if
    move "F" to px-user-data(1:1)
    call "praxo-otel" using px-otel-options px-otel-result
        px-otel-event px-user-data px-status
    if px-status not = "OTEL_HTTP"
        display "expected OTEL_HTTP, got: " px-status
        stop run returning 1
    end-if
    if px-otel-error-body-length not = 512
        display "otel error body is not bounded: "
            px-otel-error-body-length
        stop run returning 1
    end-if
    move "S" to px-user-data(1:1)
    move spaces to px-otel-endpoint
    call "praxo-otel" using px-otel-options px-otel-result
        px-otel-event px-user-data px-status
    if px-status not = "OTEL_URL"
        display "expected OTEL_URL, got: " px-status
        stop run returning 1
    end-if
    display "OTel sink tests passed"
    stop run.
scan-body.
    move 0 to ws-found-pos
    if ws-needle-length < 1
        or ws-needle-length > ws-body-length
        goback
    end-if
    perform varying ws-scan-index from ws-scan-from by 1
        until ws-scan-index > ws-body-length - ws-needle-length + 1
        if ws-body-copy(ws-scan-index:ws-needle-length)
            = ws-needle(1:ws-needle-length)
            move ws-scan-index to ws-found-pos
            exit perform
        end-if
    end-perform.
require-body.
    move 1 to ws-scan-from
    perform scan-body
    if ws-found-pos = 0
        display "missing otel body text: "
            ws-needle(1:ws-needle-length)
        stop run returning 1
    end-if.
check-trace-id.
    move '"traceId":"' to ws-needle
    move 11 to ws-needle-length
    move 1 to ws-scan-from
    perform scan-body
    if ws-found-pos = 0
        display "otel malformed trace id"
        stop run returning 1
    end-if
    compute ws-start = ws-found-pos + 11
    move '"' to ws-needle
    move 1 to ws-needle-length
    move ws-start to ws-scan-from
    perform scan-body
    if ws-found-pos = 0
        display "otel malformed trace id"
        stop run returning 1
    end-if
    compute ws-length = ws-found-pos - ws-start
    if ws-length not = 32
        display "otel trace id length: " ws-length
        stop run returning 1
    end-if.
check-span-id.
    move '"spanId":"' to ws-needle
    move 10 to ws-needle-length
    move 1 to ws-scan-from
    perform scan-body
    if ws-found-pos = 0
        display "otel malformed span id"
        stop run returning 1
    end-if
    compute ws-start = ws-found-pos + 10
    move '"' to ws-needle
    move 1 to ws-needle-length
    move ws-start to ws-scan-from
    perform scan-body
    if ws-found-pos = 0
        display "otel malformed span id"
        stop run returning 1
    end-if
    compute ws-length = ws-found-pos - ws-start
    if ws-length not = 16
        display "otel span id length: " ws-length
        stop run returning 1
    end-if.
end program otel-tests.

identification division.
program-id. fake-otel-transport recursive.
environment division.
configuration section.
repository. function all intrinsic.
data division.
working-storage section.
01 ws-mode pic x.
linkage section.
copy "otel-call.cpy".
01 px-user-data pic x(4096).
01 px-status pic x(64).
procedure division using px-otel-call px-user-data px-status.
    move spaces to px-status
    move px-user-data(1:1) to ws-mode
    if ws-mode = "F"
        move 503 to px-otel-status-code
        move all "Z" to px-otel-response
        move 600 to px-otel-response-length
    else
        move 200 to px-otel-status-code
        move "ok" to px-otel-response
        move 2 to px-otel-response-length
    end-if
    goback.
end program fake-otel-transport.
