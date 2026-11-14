       >>source format free
identification division.
program-id. provider-fallback-example.
environment division.
configuration section.
repository. function all intrinsic.
data division.
working-storage section.
01 primary-ok pic 9.
01 fallback-ok pic 9.
01 fallback-calls binary-long.
01 error-code pic x(32).
procedure division.
    move 1 to primary-ok
    move 1 to fallback-ok
    move 0 to fallback-calls
    move spaces to error-code
    if primary-ok not = 1
        add 1 to fallback-calls
    end-if
    if fallback-calls not = 0
        display "primary success path failed"
        stop run returning 1
    end-if

    move 0 to primary-ok
    move 1 to fallback-ok
    move 0 to fallback-calls
    if primary-ok not = 1
        add 1 to fallback-calls
    end-if
    if fallback-calls not = 1
        display "fallback path failed"
        stop run returning 1
    end-if

    move 0 to primary-ok
    move 0 to fallback-ok
    move "MODEL_UNAVAILABLE" to error-code
    if primary-ok not = 1 and fallback-ok not = 1
        and error-code = "MODEL_UNAVAILABLE"
        display "COBOL provider fallback example passed"
        stop run
    end-if
    display "both-failure path failed"
    stop run returning 1.
