       >>source format free
identification division.
program-id. praxo-json-generate recursive.
environment division.
configuration section.
repository. function all intrinsic.
data division.
local-storage section.
01 node-number binary-long.
01 depth-number binary-long.
01 output-position binary-long.
01 chunk pic x(16384).
01 chunk-length binary-long.
01 string-buffer.
   05 string-value pic x(2048).
   05 string-length binary-long.
01 quoted-buffer.
   05 quoted-text pic x(16384).
   05 quoted-length binary-long.
01 validation-input.
   05 validation-text pic x(32768).
   05 validation-length binary-long.
01 validation-document.
   05 validation-count binary-long.
   05 validation-nodes occurs 512 times.
      10 validation-kind pic x.
      10 validation-parent binary-long.
      10 validation-start binary-long.
      10 validation-size binary-long.
      10 validation-value pic x(2048).
      10 validation-value-length binary-long.
01 generator-stack.
   05 frames occurs 64 times.
      10 frame-node binary-long.
      10 frame-kind pic x.
      10 frame-state binary-long.
linkage section.
copy "json.cpy".
procedure division using px-json-document px-json-output px-json-error.
    initialize px-json-output
    move spaces to px-json-error
    if px-json-count < 1 or > 512
        move "JSON_INVALID" to px-json-error
        goback
    end-if
    move 0 to depth-number
    perform varying node-number from 1 by 1
        until node-number > px-json-count or px-json-error not = spaces
        perform until depth-number = 0 or px-json-error not = spaces
            if px-json-parent(node-number) = frame-node(depth-number)
                exit perform
            end-if
            perform close-container
        end-perform
        if px-json-error not = spaces exit perform end-if
        if depth-number = 0
            if node-number not = 1 or px-json-parent(node-number) not = 0
                or px-json-kind(node-number) = 'K'
                move "JSON_INVALID" to px-json-error
                exit perform
            end-if
        else
            perform separate-value
        end-if
        if px-json-error not = spaces exit perform end-if
        evaluate px-json-kind(node-number)
            when 'O' when 'A'
                if depth-number >= 64
                    move "JSON_CAPACITY" to px-json-error
                    exit perform
                end-if
                add 1 to depth-number
                move node-number to frame-node(depth-number)
                move px-json-kind(node-number) to frame-kind(depth-number)
                move 0 to frame-state(depth-number)
                if px-json-kind(node-number) = 'O'
                    move '{' to chunk
                else
                    move '[' to chunk
                end-if
                move 1 to chunk-length
                perform append-chunk
            when 'S' when 'K'
                move px-json-value(node-number) to string-value
                move px-json-value-length(node-number) to string-length
                call "praxo-json-quote" using string-buffer quoted-buffer
                    px-json-error
                if px-json-error = spaces
                    move quoted-text to chunk
                    move quoted-length to chunk-length
                    perform append-chunk
                    if px-json-kind(node-number) = 'K'
                        move ':' to chunk
                        move 1 to chunk-length
                        perform append-chunk
                    end-if
                end-if
            when 'N'
                move px-json-value-length(node-number) to chunk-length
                if chunk-length < 1 or > 2048
                    move "JSON_INVALID" to px-json-error
                else
                    move px-json-value(node-number) to chunk
                    perform append-chunk
                end-if
            when 'T'
                move 'true' to chunk
                move 4 to chunk-length
                perform append-chunk
            when 'F'
                move 'false' to chunk
                move 5 to chunk-length
                perform append-chunk
            when 'Z'
                move 'null' to chunk
                move 4 to chunk-length
                perform append-chunk
            when other move "JSON_INVALID" to px-json-error
        end-evaluate
    end-perform
    perform until depth-number = 0 or px-json-error not = spaces
        perform close-container
    end-perform
    if px-json-error = spaces
        move px-output-text to validation-text
        move px-output-length to validation-length
        call "praxo-json-parse" using validation-input validation-document
            px-json-error
        if px-json-error = spaces
            if validation-count not = px-json-count
                move "JSON_INVALID" to px-json-error
            end-if
            perform varying node-number from 1 by 1
                until node-number > px-json-count
                    or px-json-error not = spaces
                if validation-kind(node-number)
                    not = px-json-kind(node-number)
                    or validation-parent(node-number)
                        not = px-json-parent(node-number)
                    move "JSON_INVALID" to px-json-error
                end-if
                if px-json-kind(node-number) = 'N'
                    if validation-value(node-number)
                        not = px-json-value(node-number)
                        or validation-value-length(node-number)
                            not = px-json-value-length(node-number)
                        move "JSON_INVALID" to px-json-error
                    end-if
                end-if
            end-perform
        end-if
    end-if
    if px-json-error not = spaces initialize px-json-output end-if
    goback.
separate-value.
    if frame-kind(depth-number) = 'O'
        if px-json-kind(node-number) = 'K'
            if frame-state(depth-number) = 1
                move "JSON_INVALID" to px-json-error
                exit paragraph
            end-if
        else
            if frame-state(depth-number) not = 1
                move "JSON_INVALID" to px-json-error
                exit paragraph
            end-if
        end-if
    else
        if px-json-kind(node-number) = 'K'
            move "JSON_INVALID" to px-json-error
            exit paragraph
        end-if
    end-if
    if frame-state(depth-number) = 2
        move ',' to chunk
        move 1 to chunk-length
        perform append-chunk
    end-if
    if px-json-kind(node-number) = 'K'
        move 1 to frame-state(depth-number)
    else
        move 2 to frame-state(depth-number)
    end-if.
close-container.
    if frame-kind(depth-number) = 'O'
        if frame-state(depth-number) = 1
            move "JSON_INVALID" to px-json-error
            exit paragraph
        end-if
        move '}' to chunk
    else
        move ']' to chunk
    end-if
    move 1 to chunk-length
    perform append-chunk
    subtract 1 from depth-number.
append-chunk.
    if px-json-error not = spaces exit paragraph end-if
    if px-output-length + chunk-length > 16384
        move "JSON_CAPACITY" to px-json-error
        exit paragraph
    end-if
    compute output-position = px-output-length + 1
    move chunk(1:chunk-length)
        to px-output-text(output-position:chunk-length)
    add chunk-length to px-output-length.
end program praxo-json-generate.
