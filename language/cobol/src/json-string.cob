       >>source format free
identification division.
program-id. praxo-json-string recursive.
environment division.
configuration section.
repository. function all intrinsic.
data division.
local-storage section.
01 current-char pic x.
01 codepoint binary-long.
01 high-surrogate binary-long.
01 hex-number binary-long.
01 digit-value binary-long.
01 byte-value binary-long.
01 closed-string binary-char.
01 hex-digits pic x(16) value "0123456789abcdef".
linkage section.
copy "json.cpy".
procedure division using px-json-input px-json-cursor
    px-json-string px-json-error.
    initialize px-json-string
    move spaces to px-json-error
    move 0 to closed-string
    if px-json-length < 0 or > 32768
        or px-json-cursor < 1 or > px-json-length
        move "JSON_INVALID" to px-json-error
        goback
    end-if
    if px-json-text(px-json-cursor:1) not = '"'
        move "JSON_INVALID" to px-json-error
        goback
    end-if
    add 1 to px-json-cursor
    perform until px-json-cursor > px-json-length
        or px-json-error not = spaces or closed-string = 1
        move px-json-text(px-json-cursor:1) to current-char
        add 1 to px-json-cursor
        evaluate current-char
            when '"' move 1 to closed-string
            when x"5c" perform decode-escape
            when other
                compute byte-value = ord(current-char) - 1
                if byte-value < 32
                    move "JSON_INVALID" to px-json-error
                else
                    perform append-byte
                end-if
        end-evaluate
    end-perform
    if closed-string not = 1 and px-json-error = spaces
        move "JSON_INVALID" to px-json-error
    end-if
    if px-json-error = spaces
        call "praxo-utf8" using px-json-string px-json-error
    end-if
    goback.
decode-escape.
    if px-json-cursor > px-json-length
        move "JSON_INVALID" to px-json-error
        exit paragraph
    end-if
    move px-json-text(px-json-cursor:1) to current-char
    add 1 to px-json-cursor
    evaluate current-char
        when '"' when x"5c" when '/'
            compute byte-value = ord(current-char) - 1
            perform append-byte
        when 'b' move 8 to byte-value perform append-byte
        when 'f' move 12 to byte-value perform append-byte
        when 'n' move 10 to byte-value perform append-byte
        when 'r' move 13 to byte-value perform append-byte
        when 't' move 9 to byte-value perform append-byte
        when 'u'
            perform decode-hex
            if px-json-error not = spaces exit paragraph end-if
            if codepoint >= 55296 and <= 56319
                move codepoint to high-surrogate
                if px-json-cursor + 5 > px-json-length
                    move "JSON_INVALID" to px-json-error
                    exit paragraph
                end-if
                if px-json-text(px-json-cursor:2) not = x"5c75"
                    move "JSON_INVALID" to px-json-error
                    exit paragraph
                end-if
                add 2 to px-json-cursor
                perform decode-hex
                if codepoint < 56320 or > 57343
                    move "JSON_INVALID" to px-json-error
                end-if
                compute codepoint = 65536
                    + (high-surrogate - 55296) * 1024
                    + codepoint - 56320
            else
                if codepoint >= 56320 and <= 57343
                    move "JSON_INVALID" to px-json-error
                end-if
            end-if
            if px-json-error = spaces perform encode-codepoint end-if
        when other move "JSON_INVALID" to px-json-error
    end-evaluate.
decode-hex.
    move 0 to codepoint
    perform varying hex-number from 1 by 1 until hex-number > 4
        if px-json-cursor > px-json-length
            move "JSON_INVALID" to px-json-error
            exit paragraph
        end-if
        move lower-case(px-json-text(px-json-cursor:1)) to current-char
        move 1 to digit-value
        perform until digit-value > 16
            or hex-digits(digit-value:1) = current-char
            add 1 to digit-value
        end-perform
        if digit-value > 16
            move "JSON_INVALID" to px-json-error
            exit paragraph
        end-if
        compute codepoint = codepoint * 16 + digit-value - 1
        add 1 to px-json-cursor
    end-perform.
encode-codepoint.
    evaluate true
        when codepoint < 128
            move codepoint to byte-value
        when codepoint < 2048
            compute byte-value = 192 + integer(codepoint / 64)
            perform append-byte
            compute byte-value = 128 + mod(codepoint, 64)
        when codepoint < 65536
            compute byte-value = 224 + integer(codepoint / 4096)
            perform append-byte
            compute byte-value = 128 + mod(integer(codepoint / 64), 64)
            perform append-byte
            compute byte-value = 128 + mod(codepoint, 64)
        when other
            compute byte-value = 240 + integer(codepoint / 262144)
            perform append-byte
            compute byte-value = 128
                + mod(integer(codepoint / 4096), 64)
            perform append-byte
            compute byte-value = 128 + mod(integer(codepoint / 64), 64)
            perform append-byte
            compute byte-value = 128 + mod(codepoint, 64)
    end-evaluate
    perform append-byte.
append-byte.
    if px-json-error not = spaces exit paragraph end-if
    if px-string-length >= 2048
        move "JSON_CAPACITY" to px-json-error
        exit paragraph
    end-if
    add 1 to px-string-length
    move char(byte-value + 1)
        to px-string-value(px-string-length:1).
end program praxo-json-string.
