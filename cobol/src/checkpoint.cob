       >>source format free
identification division.
program-id. praxo-checkpoint recursive.
environment division.
configuration section.
repository. function all intrinsic.
data division.
working-storage section.
01 registered-count binary-long value 0.
01 registered occurs 64 times.
   05 registered-name pic x(128).
   05 registered-length binary-long.
local-storage section.
01 output-pointer binary-long.
copy "json.cpy".
copy "slice.cpy".
01 node-index binary-long.
01 found-node binary-long.
01 canonical-value pic x(32768).
01 canonical-length binary-long.
linkage section.
copy "checkpoint.cpy".
procedure division using px-checkpoint-request px-checkpoint-result.
    initialize px-checkpoint-result
    evaluate px-ck-op
        when "register" perform register-type
        when "marshal" perform marshal-value
        when "unmarshal" perform unmarshal-value
        when other move "INVALID_REQUEST" to px-ck-error
    end-evaluate
    goback.
register-type.
    if px-ck-type-length < 1 or > 128
        move "INVALID_REQUEST" to px-ck-error
        exit paragraph
    end-if
    perform find-registered
    if found-node > 0 exit paragraph end-if
    if registered-count >= 64
        move "CHECKPOINT_CAPACITY" to px-ck-error
        exit paragraph
    end-if
    add 1 to registered-count
    move px-ck-type(1:px-ck-type-length)
        to registered-name(registered-count)
    move px-ck-type-length to registered-length(registered-count).
find-registered.
    move 0 to found-node
    perform varying node-index from 1 by 1
        until node-index > registered-count
        if registered-length(node-index) = px-ck-type-length
            and registered-name(node-index)(1:px-ck-type-length)
                = px-ck-type(1:px-ck-type-length)
            move node-index to found-node
        end-if
    end-perform.
marshal-value.
    if px-ck-type-length < 1 or > 128
        or px-ck-value-length < 1 or > 32768
        move "INVALID_REQUEST" to px-ck-error
        exit paragraph
    end-if
    perform find-registered
    if found-node = 0
        move "CHECKPOINT_TYPE_NOT_ALLOWED" to px-ck-error
        exit paragraph
    end-if
    move px-ck-value(1:px-ck-value-length) to px-json-text
    move px-ck-value-length to px-json-length
    call "praxo-json-parse" using px-json-input px-json-document
        px-json-error
    if px-json-error not = spaces
        move px-json-error to px-ck-error
        exit paragraph
    end-if
    call "praxo-json-generate" using px-json-document px-json-output
        px-json-error
    if px-json-error not = spaces
        move px-json-error to px-ck-error
        exit paragraph
    end-if
    move px-output-text(1:px-output-length) to canonical-value
    move px-output-length to canonical-length
    move px-ck-type(1:px-ck-type-length) to px-string-value
    move px-ck-type-length to px-string-length
    call "praxo-json-quote" using px-json-string px-json-output
        px-json-error
    if px-json-error not = spaces
        move px-json-error to px-ck-error
        exit paragraph
    end-if
    if canonical-length + px-output-length + 20 > 32768
        move "JSON_CAPACITY" to px-ck-error
        exit paragraph
    end-if
    move spaces to px-ck-output
    move 1 to output-pointer
    string '{"type":' delimited by size
        px-output-text(1:px-output-length) delimited by size
        ',"data":' delimited by size
        canonical-value(1:canonical-length) delimited by size
        "}" delimited by size
        into px-ck-output with pointer output-pointer
    end-string
    compute px-ck-output-length = output-pointer - 1.
unmarshal-value.
    if px-ck-value-length < 1 or > 32768
        move "INVALID_REQUEST" to px-ck-error
        exit paragraph
    end-if
    move px-ck-value(1:px-ck-value-length) to px-json-text
    move px-ck-value-length to px-json-length
    call "praxo-json-parse" using px-json-input px-json-document
        px-json-error
    if px-json-error not = spaces
        move "CHECKPOINT_TYPE_NOT_ALLOWED" to px-ck-error
        exit paragraph
    end-if
    if px-json-count < 1 or px-json-kind(1) not = "O"
        move "CHECKPOINT_TYPE_NOT_ALLOWED" to px-ck-error
        exit paragraph
    end-if
    perform find-member-type
    if found-node = 0
        move "CHECKPOINT_TYPE_NOT_ALLOWED" to px-ck-error
        exit paragraph
    end-if
    if px-json-kind(found-node) not = "S"
        move "CHECKPOINT_TYPE_NOT_ALLOWED" to px-ck-error
        exit paragraph
    end-if
    move px-json-value-length(found-node) to px-ck-type-length
    if px-ck-type-length < 1 or > 128
        move "CHECKPOINT_TYPE_NOT_ALLOWED" to px-ck-error
        exit paragraph
    end-if
    move px-json-value(found-node) to px-ck-type
    perform find-registered
    if found-node = 0
        move "CHECKPOINT_TYPE_NOT_ALLOWED" to px-ck-error
        exit paragraph
    end-if
    perform find-member-data
    if found-node = 0
        move "CHECKPOINT_TYPE_NOT_ALLOWED" to px-ck-error
        exit paragraph
    end-if
    move px-ck-value(1:px-ck-value-length) to px-slice-source
    move px-ck-value-length to px-slice-source-length
    compute px-slice-start = px-json-start(found-node)
    compute px-slice-size = px-json-size(found-node)
    call "praxo-json-slice" using px-slice-request px-slice-result
    if px-slice-error not = spaces
        move px-slice-error to px-ck-error
        exit paragraph
    end-if
    if px-slice-output-length > 32768
        move "JSON_CAPACITY" to px-ck-error
        exit paragraph
    end-if
    move px-slice-output(1:px-slice-output-length) to px-ck-output
    move px-slice-output-length to px-ck-output-length.
find-member-type.
    move 0 to found-node
    perform varying node-index from 2 by 1
        until node-index >= px-json-count
        if px-json-parent(node-index) = 1
            and px-json-kind(node-index) = "K"
            and px-json-value-length(node-index) = 4
            and px-json-value(node-index)(1:4) = "type"
            compute found-node = node-index + 1
        end-if
    end-perform.
find-member-data.
    move 0 to found-node
    perform varying node-index from 2 by 1
        until node-index >= px-json-count
        if px-json-parent(node-index) = 1
            and px-json-kind(node-index) = "K"
            and px-json-value-length(node-index) = 4
            and px-json-value(node-index)(1:4) = "data"
            compute found-node = node-index + 1
        end-if
    end-perform.
end program praxo-checkpoint.

