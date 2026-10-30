       >>source format free
identification division.
program-id. registry-tests.
environment division.
configuration section.
repository. function all intrinsic.
data division.
working-storage section.
copy "registry-state.cpy" replacing ==px-registry-state== by ==registry-a==.
copy "registry-state.cpy" replacing ==px-registry-state== by ==registry-b==.
copy "registry.cpy".
01 i binary-long.
01 suffix pic 99.
01 failures binary-long value 0.
procedure division.
    initialize registry-a registry-b px-registry-request
    move "register" to px-reg-op
    move 64 to px-reg-name-length px-reg-program-length
    move all "x" to px-reg-name
    move all "p" to px-reg-program
    move 256 to px-reg-description-length
    move all "d" to px-reg-description
    move 16 to px-reg-risk-length
    move all "r" to px-reg-risk
    perform scoped-a
    if px-reg-error not = spaces perform fail-case end-if
    move "get" to px-reg-op
    call "praxo-registry-scoped" using registry-b
        px-registry-request px-registry-result
    if px-reg-error not = "TOOL_NOT_FOUND"
        perform fail-case
    end-if
    perform scoped-a
    if px-reg-count not = 1 or px-reg-entry-name(1) not = px-reg-name
        or px-reg-entry-description(1) not = px-reg-description
        or px-reg-entry-program(1) not = px-reg-program
        or px-reg-entry-risk(1) not = px-reg-risk
        perform fail-case
    end-if
    move "clear" to px-reg-op
    perform scoped-a
    perform varying i from 1 by 1 until i > 32
        initialize px-registry-request
        move "register" to px-reg-op
        move i to suffix
        string "tool-" suffix into px-reg-name end-string
        move 7 to px-reg-name-length
        move "echo-program" to px-reg-program
        move 12 to px-reg-program-length
        perform scoped-a
        if px-reg-error not = spaces perform fail-case end-if
    end-perform
    move "extra" to px-reg-name
    move 5 to px-reg-name-length
    perform scoped-a
    if px-reg-error not = "REGISTRY_CAPACITY"
        perform fail-case
    end-if
    move "tool-01" to px-reg-name
    move 7 to px-reg-name-length
    move "replacement" to px-reg-description
    move 11 to px-reg-description-length
    perform scoped-a
    if px-reg-error not = spaces perform fail-case end-if
    move "get" to px-reg-op
    perform scoped-a
    if px-reg-entry-description(1) not = "replacement"
        perform fail-case
    end-if
    move "list" to px-reg-op
    perform scoped-a
    if px-reg-count not = 32
        or px-reg-entry-name(1) not = "tool-01"
        or px-reg-entry-name(32) not = "tool-32"
        perform fail-case
    end-if
    move "clear" to px-reg-op
    perform scoped-a
    move "list" to px-reg-op
    perform scoped-a
    if px-reg-count not = 0 perform fail-case end-if
    move "get" to px-reg-op
    perform scoped-a
    if px-reg-error not = "TOOL_NOT_FOUND"
        perform fail-case
    end-if
    move 33 to entry-count of registry-a
    move "list" to px-reg-op
    perform scoped-a
    if px-reg-error not = "INVALID_REQUEST"
        perform fail-case
    end-if
    move "clear" to px-reg-op
    perform scoped-a
    if entry-count of registry-a not = 0 perform fail-case end-if
    move "register" to px-reg-op
    move -1 to px-reg-name-length
    perform scoped-a
    if px-reg-error not = "INVALID_REQUEST" perform fail-case end-if
    move 65 to px-reg-name-length
    perform scoped-a
    if px-reg-error not = "INVALID_REQUEST" perform fail-case end-if
    move 0 to px-reg-name-length
    move spaces to px-reg-name px-reg-program
    move 0 to px-reg-program-length
    perform scoped-a
    if px-reg-error not = spaces perform fail-case end-if
    move "get" to px-reg-op
    perform scoped-a
    if px-reg-count not = 1 perform fail-case end-if
    move 65 to stored-name-length of registry-a(1)
    perform scoped-a
    if px-reg-error not = "INVALID_REQUEST" perform fail-case end-if
    move "clear" to px-reg-op
    perform scoped-a
    if entry-count of registry-a not = 0 perform fail-case end-if
    if failures = 0
        display "PASS: scoped registry capacity, replacement, clear, isolation"
    else
        move 1 to return-code
    end-if
    goback.
scoped-a.
    call "praxo-registry-scoped" using registry-a
        px-registry-request px-registry-result.
fail-case.
    add 1 to failures
    display "FAIL: registry op=" px-reg-op " error=" px-reg-error.
end program registry-tests.
