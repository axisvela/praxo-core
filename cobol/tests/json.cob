       >>source format free
identification division.
program-id. json-tests.
environment division.
configuration section.
repository. function all intrinsic.
data division.
working-storage section.
copy "json.cpy".
01 failures binary-long value 0.
01 cases binary-long value 0.
01 expected-valid binary-char.
01 sample-number binary-long.
01 saved-string pic x(2048).
01 saved-length binary-long.
procedure division.
    move 1 to expected-valid
    move '{"a":[true,false,null,-1.25e+2,{"b":"x,y"}]}'
        to px-json-text
    perform parse-case
    if px-json-count not = 10 or px-json-kind(1) not = 'O'
        or px-json-kind(2) not = 'K'
        or px-json-parent(3) not = 1
        or px-json-value(2) not = 'a'
        or px-json-value(10) not = 'x,y'
        add 1 to failures
        display "FAIL: parsed document tree count=" px-json-count
            " root=" px-json-kind(1) " key=" px-json-kind(2)
            " parent=" px-json-parent(3)
            " key-value=" trim(px-json-value(2))
            " leaf=" trim(px-json-value(10))
    end-if
    call "praxo-json-generate" using px-json-document px-json-output
        px-json-error
    if px-json-error not = spaces
        or px-output-text not = trim(px-json-text trailing)
        add 1 to failures
        display "FAIL: nested JSON generation"
    end-if
    move 1 to px-json-count
    move 'N' to px-json-kind(1)
    move 0 to px-json-parent(1)
    move 'true' to px-json-value(1)
    move 4 to px-json-value-length(1)
    call "praxo-json-generate" using px-json-document px-json-output
        px-json-error
    if px-json-error = spaces or px-output-length not = 0
        add 1 to failures
        display "FAIL: invalid numeric generation"
    end-if
    move '"\u4e2d\u6587 \ud83d\ude00"' to px-json-text
    perform parse-case
    if px-json-value-length(1) not = 11
        or px-json-value(1)(1:11) not = x"e4b8ade6968720f09f9880"
        add 1 to failures
        display "FAIL: Unicode decoding"
    end-if
    move '"\"\\\/\b\f\n\r\t\u0000 "' to px-json-text
    perform parse-case
    if px-json-value-length(1) not = 10
        add 1 to failures
        display "FAIL: escape decoding"
    end-if
    move px-json-value(1) to px-string-value saved-string
    move px-json-value-length(1) to px-string-length saved-length
    call "praxo-json-quote" using px-json-string px-json-output
        px-json-error
    if px-json-error not = spaces
        add 1 to failures
        display "FAIL: quote generation"
    end-if
    move px-output-text to px-json-text
    perform parse-case
    if px-json-value(1) not = saved-string
        or px-json-value-length(1) not = saved-length
        add 1 to failures
        display "FAIL: quote roundtrip preserves bytes and spaces"
    end-if
    move 0 to expected-valid
    perform varying sample-number from 1 by 1 until sample-number > 22
        evaluate sample-number
            when 1 move '{}' & '{}' to px-json-text
            when 2 move '[1,]' to px-json-text
            when 3 move '{"a":1,}' to px-json-text
            when 4 move '{a:1}' to px-json-text
            when 5 move '[01]' to px-json-text
            when 6 move '[1.]' to px-json-text
            when 7 move '[1e+]' to px-json-text
            when 8 move '"\q"' to px-json-text
            when 9 move '"\ud800"' to px-json-text
            when 10 move '"\udc00"' to px-json-text
            when 11 move '"\ud800\u0041"' to px-json-text
            when 12 move '"\u00xz"' to px-json-text
            when 13 move '[true false]' to px-json-text
            when 14 move '{"a" 1}' to px-json-text
            when 15 move '{"a":}' to px-json-text
            when 16 move '[}' to px-json-text
            when 17 move '"unterminated' to px-json-text
            when 18 move spaces to px-json-text
            when 19 move x"22c08022" to px-json-text
            when 20 move x"22eda08022" to px-json-text
            when 21 move x"22f490808022" to px-json-text
            when 22 move x"220a22" to px-json-text
        end-evaluate
        perform parse-case
    end-perform
    move all '[' to px-json-text
    move 65 to px-json-length
    call "praxo-json-parse" using px-json-input px-json-document
        px-json-error
    if px-json-error not = "JSON_CAPACITY"
        add 1 to failures
        display "FAIL: nesting capacity"
    end-if
    move all x"01" to px-string-value
    move 2048 to px-string-length
    call "praxo-json-quote" using px-json-string px-json-output
        px-json-error
    if px-json-error not = spaces or px-output-length not = 12290
        add 1 to failures
        display "FAIL: maximum escaping expansion"
    end-if
    if failures not = 0
        display "FAIL: JSON assertions=" failures
        move 1 to return-code
    else
        display "PASS: JSON parse, Unicode, quote, and capacity tests"
        move 0 to return-code
    end-if
    goback.
parse-case.
    add 1 to cases
    compute px-json-length = length(trim(px-json-text trailing))
    call "praxo-json-parse" using px-json-input px-json-document
        px-json-error
    if (expected-valid = 1 and px-json-error not = spaces)
        or (expected-valid = 0 and px-json-error = spaces)
        add 1 to failures
        display "FAIL: JSON case " cases " error=" trim(px-json-error)
    end-if
    if expected-valid = 0 and px-json-count not = 0
        add 1 to failures
        display "FAIL: invalid JSON exposed partial document"
    end-if.
end program json-tests.
