       >>source format free
identification division.
program-id. retry-example.
environment division.
configuration section.
repository. function all intrinsic.
data division.
working-storage section.
01 attempt binary-long.
01 calls binary-long.
01 failures binary-long.
01 succeeded pic 9.
procedure division.
    move 0 to calls
    move 2 to failures
    move 0 to succeeded
    perform varying attempt from 1 by 1 until attempt > 3
        add 1 to calls
        if calls > failures
            move 1 to succeeded
            exit perform
        end-if
    end-perform
    if succeeded not = 1 or calls not = 3
        display "transient retry failed"
        stop run returning 1
    end-if

    move 0 to calls
    move 3 to failures
    move 0 to succeeded
    perform varying attempt from 1 by 1 until attempt > 3
        add 1 to calls
        if calls > failures
            move 1 to succeeded
        end-if
    end-perform
    if succeeded = 1 or calls not = 3
        display "exhausted retry failed"
        stop run returning 1
    end-if

    display "COBOL retry example passed"
    stop run.
