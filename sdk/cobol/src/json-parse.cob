       >>source format free
identification division.
program-id. praxo-json-parse recursive.
environment division.
configuration section.
repository. function all intrinsic.
data division.
local-storage section.
01 parse-position binary-long.
01 node-number binary-long.
01 node-start binary-long.
01 node-size binary-long.
01 depth-number binary-long.
01 root-state binary-long.
01 current-state binary-long.
01 current-char pic x.
01 literal-value pic x(5).
01 literal-length binary-long.
01 decoded-string.
   05 string-value pic x(2048).
   05 string-length binary-long.
01 parse-stack.
   05 frames occurs 64 times.
      10 frame-node binary-long.
      10 frame-state binary-long.
linkage section.
copy "json.cpy".
procedure division using px-json-input px-json-document px-json-error.
    initialize px-json-document
    move spaces to px-json-error
    if px-json-length < 1 or > 32768
        move "JSON_INVALID" to px-json-error
        goback
    end-if
    move 1 to parse-position
    move 0 to depth-number root-state
    perform until px-json-error not = spaces
        perform skip-space
        if depth-number = 0 and root-state = 1
            if parse-position <= px-json-length
                move "JSON_INVALID" to px-json-error
            end-if
            exit perform
        end-if
        if parse-position > px-json-length
            move "JSON_INVALID" to px-json-error
            exit perform
        end-if
        move 0 to current-state
        if depth-number > 0
            move frame-state(depth-number) to current-state
        end-if
        evaluate true
            when (current-state = 1 or 2) and current-char = ']'
                perform close-container
            when (current-state = 4 or 7) and current-char = '}'
                perform close-container
            when current-state = 2 or 7
                if current-char not = ','
                    move "JSON_INVALID" to px-json-error
                else
                    if current-state = 2
                        move 3 to frame-state(depth-number)
                    else
                        move 8 to frame-state(depth-number)
                    end-if
                    add 1 to parse-position
                end-if
            when current-state = 4 or 8
                if current-char not = '"'
                    move "JSON_INVALID" to px-json-error
                else
                    perform add-node
                    if px-json-error = spaces
                        move 'K' to px-json-kind(node-number)
                        perform parse-string
                        move 5 to frame-state(depth-number)
                    end-if
                end-if
            when current-state = 5
                if current-char not = ':'
                    move "JSON_INVALID" to px-json-error
                else
                    move 6 to frame-state(depth-number)
                    add 1 to parse-position
                end-if
            when other perform parse-value
        end-evaluate
    end-perform
    if px-json-error not = spaces move 0 to px-json-count end-if
    goback.
peek-char.
    move low-values to current-char
    if parse-position <= px-json-length
        move px-json-text(parse-position:1) to current-char
    end-if.
skip-space.
    perform peek-char
    perform until parse-position > px-json-length
        or (current-char not = space and x"09" and x"0a" and x"0d")
        add 1 to parse-position
        perform peek-char
    end-perform.
add-node.
    if px-json-count >= 512
        move "JSON_CAPACITY" to px-json-error
        exit paragraph
    end-if
    add 1 to px-json-count
    move px-json-count to node-number
    move parse-position to px-json-start(node-number) node-start
    if depth-number > 0
        move frame-node(depth-number) to px-json-parent(node-number)
    end-if.
parse-value.
    perform add-node
    if px-json-error not = spaces exit paragraph end-if
    if depth-number = 0
        move 1 to root-state
    else
        if current-state = 6
            move 7 to frame-state(depth-number)
        else
            move 2 to frame-state(depth-number)
        end-if
    end-if
    evaluate true
        when current-char = '{' or '['
            if depth-number >= 64
                move "JSON_CAPACITY" to px-json-error
                exit paragraph
            end-if
            add 1 to depth-number
            move node-number to frame-node(depth-number)
            if current-char = '{'
                move 'O' to px-json-kind(node-number)
                move 4 to frame-state(depth-number)
            else
                move 'A' to px-json-kind(node-number)
                move 1 to frame-state(depth-number)
            end-if
            add 1 to parse-position
        when current-char = '"'
            move 'S' to px-json-kind(node-number)
            perform parse-string
        when current-char = '-' or (current-char >= '0' and <= '9')
            move 'N' to px-json-kind(node-number)
            perform parse-number
        when current-char = 't'
            move 'T' to px-json-kind(node-number)
            move 'true' to literal-value
            move 4 to literal-length
            perform parse-literal
        when current-char = 'f'
            move 'F' to px-json-kind(node-number)
            move 'false' to literal-value
            move 5 to literal-length
            perform parse-literal
        when current-char = 'n'
            move 'Z' to px-json-kind(node-number)
            move 'null' to literal-value
            move 4 to literal-length
            perform parse-literal
        when other move "JSON_INVALID" to px-json-error
    end-evaluate.
close-container.
    move frame-node(depth-number) to node-number
    compute px-json-size(node-number) = parse-position
        - px-json-start(node-number) + 1
    subtract 1 from depth-number
    add 1 to parse-position.
parse-string.
    call "praxo-json-string" using px-json-input parse-position
        decoded-string px-json-error
    if px-json-error = spaces
        move string-value to px-json-value(node-number)
        move string-length to px-json-value-length(node-number)
        compute px-json-size(node-number) = parse-position - node-start
    end-if.
parse-literal.
    if parse-position + literal-length - 1 > px-json-length
        move "JSON_INVALID" to px-json-error
        exit paragraph
    end-if
    if px-json-text(parse-position:literal-length)
        not = literal-value(1:literal-length)
        move "JSON_INVALID" to px-json-error
        exit paragraph
    end-if
    add literal-length to parse-position
    perform save-primitive.
parse-number.
    if current-char = '-'
        add 1 to parse-position
        perform peek-char
    end-if
    evaluate true
        when current-char = '0'
            add 1 to parse-position
            perform peek-char
        when current-char >= '1' and <= '9'
            perform scan-digits
        when other
            move "JSON_INVALID" to px-json-error
            exit paragraph
    end-evaluate
    if current-char = '.'
        add 1 to parse-position
        perform peek-char
        perform require-digits
    end-if
    if current-char = 'e' or 'E'
        add 1 to parse-position
        perform peek-char
        if current-char = '+' or '-'
            add 1 to parse-position
            perform peek-char
        end-if
        perform require-digits
    end-if
    if px-json-error = spaces perform save-primitive end-if.
require-digits.
    if current-char < '0' or > '9'
        move "JSON_INVALID" to px-json-error
    else
        perform scan-digits
    end-if.
scan-digits.
    perform until current-char < '0' or > '9'
        add 1 to parse-position
        perform peek-char
    end-perform.
save-primitive.
    compute node-size = parse-position - node-start
    if node-size > 2048
        move "JSON_CAPACITY" to px-json-error
        exit paragraph
    end-if
    move node-size to px-json-size(node-number)
        px-json-value-length(node-number)
    move px-json-text(node-start:node-size)
        to px-json-value(node-number).
end program praxo-json-parse.
