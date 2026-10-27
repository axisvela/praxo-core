       >>source format free
identification division.
program-id. praxo-utf8 recursive.
environment division.
configuration section.
repository. function all intrinsic.
data division.
local-storage section.
01 byte-number binary-long.
01 byte-value binary-long.
01 remaining-bytes binary-long.
01 low-byte binary-long.
01 high-byte binary-long.
linkage section.
copy "json.cpy".
procedure division using px-json-string px-json-error.
    move spaces to px-json-error
    if px-string-length < 0 or > 2048
        move "JSON_CAPACITY" to px-json-error
        goback
    end-if
    move 0 to remaining-bytes
    perform varying byte-number from 1 by 1
        until byte-number > px-string-length
        compute byte-value = ord(px-string-value(byte-number:1)) - 1
        if remaining-bytes > 0
            if byte-value < low-byte or > high-byte
                move "JSON_INVALID" to px-json-error
                goback
            end-if
            subtract 1 from remaining-bytes
            move 128 to low-byte
            move 191 to high-byte
        else
            move 128 to low-byte
            move 191 to high-byte
            evaluate true
                when byte-value < 128 continue
                when byte-value >= 194 and <= 223
                    move 1 to remaining-bytes
                when byte-value >= 224 and <= 239
                    move 2 to remaining-bytes
                    if byte-value = 224 move 160 to low-byte end-if
                    if byte-value = 237 move 159 to high-byte end-if
                when byte-value >= 240 and <= 244
                    move 3 to remaining-bytes
                    if byte-value = 240 move 144 to low-byte end-if
                    if byte-value = 244 move 143 to high-byte end-if
                when other
                    move "JSON_INVALID" to px-json-error
                    goback
            end-evaluate
        end-if
    end-perform
    if remaining-bytes not = 0
        move "JSON_INVALID" to px-json-error
    end-if
    goback.
end program praxo-utf8.
