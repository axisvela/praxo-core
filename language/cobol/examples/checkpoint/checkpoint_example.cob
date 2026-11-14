       >>source format free
identification division.
program-id. checkpoint-example.
environment division.
configuration section.
repository. function all intrinsic.
data division.
working-storage section.
copy "checkpoint.cpy".
procedure division.
    initialize px-checkpoint-request px-checkpoint-result
    move "register" to px-ck-op
    move "order" to px-ck-type
    move 5 to px-ck-type-length
    call "praxo-checkpoint" using px-checkpoint-request px-checkpoint-result
    if px-ck-error not = spaces
        display "register failed: " px-ck-error
        stop run returning 1
    end-if

    move "marshal" to px-ck-op
    move '{"value":"x"}' to px-ck-value
    compute px-ck-value-length = function length(
        function trim(px-ck-value trailing))
    call "praxo-checkpoint" using px-checkpoint-request px-checkpoint-result
    if px-ck-error not = spaces
        display "marshal failed: " px-ck-error
        stop run returning 1
    end-if

    move px-ck-output(1:px-ck-output-length) to px-ck-value
    move px-ck-output-length to px-ck-value-length
    move "unmarshal" to px-ck-op
    call "praxo-checkpoint" using px-checkpoint-request px-checkpoint-result
    if px-ck-error not = spaces or px-ck-output not = '{"value":"x"}'
        display "roundtrip failed: " px-ck-error
        stop run returning 1
    end-if

    move "marshal" to px-ck-op
    move "missing" to px-ck-type
    move 7 to px-ck-type-length
    move "{}" to px-ck-value
    move 2 to px-ck-value-length
    call "praxo-checkpoint" using px-checkpoint-request px-checkpoint-result
    if px-ck-error(1:27) not = "CHECKPOINT_TYPE_NOT_ALLOWED"
        display "unregistered type was accepted"
        stop run returning 1
    end-if

    display "COBOL checkpoint example passed"
    stop run.
