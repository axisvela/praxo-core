       >>source format free
identification division.
program-id. streaming-example.
environment division.
configuration section.
repository. function all intrinsic.
data division.
working-storage section.
01 chunk pic x(16).
01 output-buffer pic x(64).
01 output-length binary-long.
procedure division.
    move spaces to output-buffer
    move 0 to output-length

    move "status: " to chunk
    move chunk(1:8) to output-buffer(1:8)
    add 8 to output-length

    move "green" to chunk
    move chunk(1:5) to output-buffer(output-length + 1:5)
    add 5 to output-length

    if output-buffer(1:output-length) not = "status: green"
        display "deltas did not reconstruct the output"
        stop run returning 1
    end-if

    display "COBOL streaming example passed"
    stop run.
