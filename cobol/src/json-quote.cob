       >>source format free
identification division.
program-id. praxo-json-quote recursive.
environment division.
configuration section.
repository. function all intrinsic.
data division.
local-storage section.
01 input-position binary-long.
01 output-position binary-long.
01 byte-value binary-long.
01 digit-number binary-long.
01 hex-digits pic x(16) value "0123456789abcdef".
linkage section.
copy "json.cpy".
procedure division using px-json-string px-json-output px-json-error.
    initialize px-json-output
    call "praxo-utf8" using px-json-string px-json-error
    if px-json-error not = spaces goback end-if
    move 1 to output-position
    move '"' to px-output-text(output-position:1)
    add 1 to output-position
    perform varying input-position from 1 by 1
        until input-position > px-string-length
        compute byte-value = ord(px-string-value(input-position:1)) - 1
        evaluate true
            when byte-value < 32
                move x"5c753030" to px-output-text(output-position:4)
                add 4 to output-position
                compute digit-number = integer(byte-value / 16) + 1
                move hex-digits(digit-number:1)
                    to px-output-text(output-position:1)
                add 1 to output-position
                compute digit-number = mod(byte-value, 16) + 1
                move hex-digits(digit-number:1)
                    to px-output-text(output-position:1)
                add 1 to output-position
            when byte-value = 34 or 92
                move x"5c" to px-output-text(output-position:1)
                add 1 to output-position
                move px-string-value(input-position:1)
                    to px-output-text(output-position:1)
                add 1 to output-position
            when other
                move px-string-value(input-position:1)
                    to px-output-text(output-position:1)
                add 1 to output-position
        end-evaluate
    end-perform
    move '"' to px-output-text(output-position:1)
    move output-position to px-output-length
    goback.
end program praxo-json-quote.
