       >>source format free
identification division.
program-id. sse-tests.
environment division.
configuration section.
repository. function all intrinsic.
data division.
working-storage section.
copy "sse.cpy".
01 sse-pointer binary-long.
01 failures binary-long value 0.
01 assertion-ok pic 9.
01 assertion-label pic x(128).
procedure division.
    perform complete-stream-case
    perform finish-reason-case
    perform truncated-stream-case
    perform half-packet-case
    if failures = 0
        display "PASS: 4 native COBOL SSE cases"
    else
        display "FAIL: " failures " SSE assertions"
        move 1 to return-code
    end-if
    goback.
complete-stream-case.
    initialize px-sse-request px-sse-result
    move spaces to px-sse-text
    move 1 to sse-pointer
    string 'data: {"choices":[{"delta":{"content":"hi"}}]}'
            delimited by size
        x"0a" delimited by size
        x"0a" delimited by size
        "data: [DONE]" delimited by size
        x"0a" delimited by size
        x"0a" delimited by size
        into px-sse-text with pointer sse-pointer
    compute px-sse-length = sse-pointer - 1
    call "praxo-sse" using px-sse-request px-sse-result
    move 1 to assertion-ok
    if px-sse-error not = spaces or px-sse-done not = 1
        or px-sse-event-count not = 1
        or px-sse-content-length not = 2
        or px-sse-content(1:2) not = "hi"
        move 0 to assertion-ok
    end-if
    move "sse complete stream" to assertion-label
    perform assert-ok.
finish-reason-case.
    initialize px-sse-request px-sse-result
    move spaces to px-sse-text
    move 1 to sse-pointer
    string 'data: {"choices":[{"delta":{"content":"ok"},"finish_reason":"stop"}]}'
            delimited by size
        x"0a" delimited by size
        x"0a" delimited by size
        into px-sse-text with pointer sse-pointer
    compute px-sse-length = sse-pointer - 1
    call "praxo-sse" using px-sse-request px-sse-result
    move 1 to assertion-ok
    if px-sse-error not = spaces or px-sse-done not = 1
        or px-sse-content(1:2) not = "ok"
        move 0 to assertion-ok
    end-if
    move "sse finish reason" to assertion-label
    perform assert-ok.
truncated-stream-case.
    initialize px-sse-request px-sse-result
    move spaces to px-sse-text
    move 1 to sse-pointer
    string 'data: {"choices":[{"delta":{"content":"hi"}}]}'
            delimited by size
        x"0a" delimited by size
        x"0a" delimited by size
        into px-sse-text with pointer sse-pointer
    compute px-sse-length = sse-pointer - 1
    call "praxo-sse" using px-sse-request px-sse-result
    move 1 to assertion-ok
    if px-sse-error not = "MODEL_STREAM" move 0 to assertion-ok end-if
    move "sse truncated stream" to assertion-label
    perform assert-ok.
half-packet-case.
    initialize px-sse-request px-sse-result
    move spaces to px-sse-text
    move 1 to sse-pointer
    string 'data: {"choices":[{"delta":{"content":"hi"}}]}'
            delimited by size
        x"0a" delimited by size
        x"0a" delimited by size
        'data: {"choices' delimited by size
        x"0a" delimited by size
        into px-sse-text with pointer sse-pointer
    compute px-sse-length = sse-pointer - 1
    call "praxo-sse" using px-sse-request px-sse-result
    move 1 to assertion-ok
    if px-sse-error not = "MODEL_STREAM" move 0 to assertion-ok end-if
    move "sse half packet" to assertion-label
    perform assert-ok.
assert-ok.
    if assertion-ok = 0
        add 1 to failures
        display "FAIL: " trim(assertion-label)
    end-if.
end program sse-tests.
