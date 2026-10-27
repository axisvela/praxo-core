       >>source format free
identification division.
program-id. praxo-pattern-check recursive.
environment division.
configuration section.
repository. function all intrinsic.
data division.
local-storage section.
01 states occurs 8193 times pic 9.
01 next-states occurs 8193 times pic 9.
01 allowed occurs 256 times pic 9.
01 position-number binary-long.
01 pattern-index binary-long.
01 atom-index binary-long.
01 range-index binary-long.
01 class-start binary-long.
01 class-end binary-long.
01 code-value binary-long.
01 any-match pic 9.
01 anchored-start pic 9.
01 anchored-end pic 9.
01 negate-class pic 9.
01 optional-atom pic 9.
01 repeated-atom pic 9.
01 range-low binary-long.
01 range-high binary-long.
01 pattern-char pic x.
linkage section.
copy "pattern.cpy".
procedure division using px-pattern-request px-pattern-result.
    initialize px-pattern-result
    if px-pat-pattern-length < 0 or > 4096
        or px-pat-text-length < 0 or > 8192
        move "SCHEMA_PATTERN_UNSUPPORTED" to px-pat-error
        goback
    end-if
    if px-pat-pattern-length * px-pat-text-length > 4194304
        move "SCHEMA_PATTERN_UNSUPPORTED" to px-pat-error
        goback
    end-if
    perform validate-ascii
    if px-pat-error not = spaces goback end-if
    perform initialize-states
    if px-pat-pattern-length = 0
        move 1 to px-pat-matched
        goback
    end-if
    move 1 to pattern-index
    move 0 to anchored-start anchored-end
    if px-pat-pattern(1:1) = "^"
        move 1 to anchored-start
        add 1 to pattern-index
    end-if
    if pattern-index <= px-pat-pattern-length
        if px-pat-pattern(px-pat-pattern-length:1) = "$"
            move 1 to anchored-end
        end-if
    end-if
    perform until pattern-index > px-pat-pattern-length
        if anchored-end = 1
            and pattern-index = px-pat-pattern-length
            exit perform
        end-if
        move px-pat-pattern(pattern-index:1) to pattern-char
        move 0 to optional-atom repeated-atom negate-class
        perform clear-allowed
        evaluate pattern-char
            when "."
                perform varying atom-index from 1 by 1
                    until atom-index > 256
                    move 1 to allowed(atom-index)
                end-perform
                move 0 to allowed(11)
            when "["
                add 1 to pattern-index
                if pattern-index <= px-pat-pattern-length
                    if px-pat-pattern(pattern-index:1) = "^"
                        move 1 to negate-class
                        add 1 to pattern-index
                    end-if
                end-if
                move pattern-index to class-start
                perform until pattern-index > px-pat-pattern-length
                    if px-pat-pattern(pattern-index:1) = "]"
                        exit perform
                    end-if
                    if px-pat-pattern(pattern-index:1) = x"5c"
                        move "SCHEMA_PATTERN_UNSUPPORTED"
                            to px-pat-error
                        goback
                    end-if
                    compute code-value = function ord(
                        px-pat-pattern(pattern-index:1)) - 1
                    add 1 to pattern-index
                    if pattern-index + 1 <= px-pat-pattern-length
                        if px-pat-pattern(pattern-index:1) = "-"
                            and px-pat-pattern(pattern-index + 1:1)
                                not = "]"
                            compute range-high = function ord(
                                px-pat-pattern(pattern-index + 1:1)) - 1
                            if range-high < code-value
                                move "SCHEMA_PATTERN_UNSUPPORTED" to px-pat-error
                                goback
                            end-if
                            perform varying atom-index from code-value by 1
                                until atom-index > range-high
                                move 1 to allowed(atom-index + 1)
                            end-perform
                            add 2 to pattern-index
                        else
                            move 1 to allowed(code-value + 1)
                        end-if
                    else
                        move 1 to allowed(code-value + 1)
                    end-if
                end-perform
                if pattern-index > px-pat-pattern-length
                    or pattern-index = class-start
                    move "SCHEMA_PATTERN_UNSUPPORTED" to px-pat-error
                    goback
                end-if
                if negate-class = 1
                    perform varying atom-index from 1 by 1
                        until atom-index > 256
                        if allowed(atom-index) = 1
                            move 0 to allowed(atom-index)
                        else
                            move 1 to allowed(atom-index)
                        end-if
                    end-perform
                end-if
            when x"5c"
                add 1 to pattern-index
                if pattern-index > px-pat-pattern-length
                    move "SCHEMA_PATTERN_UNSUPPORTED" to px-pat-error
                    goback
                end-if
                move px-pat-pattern(pattern-index:1) to pattern-char
                evaluate pattern-char
                    when "d"
                        perform varying atom-index from 49 by 1
                            until atom-index > 58
                            move 1 to allowed(atom-index)
                        end-perform
                    when "w"
                        perform varying atom-index from 49 by 1
                            until atom-index > 58
                            move 1 to allowed(atom-index)
                        end-perform
                        perform varying atom-index from 66 by 1
                            until atom-index > 91
                            move 1 to allowed(atom-index)
                        end-perform
                        perform varying atom-index from 98 by 1
                            until atom-index > 123
                            move 1 to allowed(atom-index)
                        end-perform
                        move 1 to allowed(96)
                    when "s"
                        move 1 to allowed(10) allowed(11) allowed(12)
                            allowed(13) allowed(14) allowed(33)
                    when "n"
                        move 1 to allowed(11)
                    when "r"
                        move 1 to allowed(14)
                    when "t"
                        move 1 to allowed(10)
                    when "f"
                        move 1 to allowed(13)
                    when other
                        if (pattern-char >= "a" and <= "z")
                            or (pattern-char >= "A" and <= "Z")
                            or (pattern-char >= "0" and <= "9")
                            move "SCHEMA_PATTERN_UNSUPPORTED" to px-pat-error
                            goback
                        end-if
                        compute code-value = function ord(pattern-char) - 1
                        move 1 to allowed(code-value + 1)
                end-evaluate
            when "("
                move "SCHEMA_PATTERN_UNSUPPORTED" to px-pat-error
                goback
            when ")"
                move "SCHEMA_PATTERN_UNSUPPORTED" to px-pat-error
                goback
            when "|"
                move "SCHEMA_PATTERN_UNSUPPORTED" to px-pat-error
                goback
            when "{"
                move "SCHEMA_PATTERN_UNSUPPORTED" to px-pat-error
                goback
            when "}"
                move "SCHEMA_PATTERN_UNSUPPORTED" to px-pat-error
                goback
            when "*"
                move "SCHEMA_PATTERN_UNSUPPORTED" to px-pat-error
                goback
            when "+"
                move "SCHEMA_PATTERN_UNSUPPORTED" to px-pat-error
                goback
            when "?"
                move "SCHEMA_PATTERN_UNSUPPORTED" to px-pat-error
                goback
            when "$"
                move "SCHEMA_PATTERN_UNSUPPORTED" to px-pat-error
                goback
            when "^"
                move "SCHEMA_PATTERN_UNSUPPORTED" to px-pat-error
                goback
            when other
                compute code-value = function ord(pattern-char) - 1
                move 1 to allowed(code-value + 1)
        end-evaluate
        add 1 to pattern-index
        if pattern-index <= px-pat-pattern-length
            evaluate px-pat-pattern(pattern-index:1)
                when "*"
                    move 1 to optional-atom repeated-atom
                    add 1 to pattern-index
                when "+"
                    move 1 to repeated-atom
                    add 1 to pattern-index
                when "?"
                    move 1 to optional-atom
                    add 1 to pattern-index
                when other
                    continue
            end-evaluate
        end-if
        perform advance-states
    end-perform
    if anchored-end = 1
        move states(px-pat-text-length + 1) to px-pat-matched
    else
        move 0 to any-match
        perform varying atom-index from 1 by 1
            until atom-index > px-pat-text-length + 1
            if states(atom-index) = 1
                move 1 to any-match
                exit perform
            end-if
        end-perform
        move any-match to px-pat-matched
    end-if
    goback.
validate-ascii.
    perform varying atom-index from 1 by 1
        until atom-index > px-pat-pattern-length
        if function ord(px-pat-pattern(atom-index:1)) > 128
            move "SCHEMA_PATTERN_UNSUPPORTED" to px-pat-error
            exit paragraph
        end-if
    end-perform
    perform varying atom-index from 1 by 1
        until atom-index > px-pat-text-length
        if function ord(px-pat-text(atom-index:1)) > 128
            move "SCHEMA_PATTERN_UNSUPPORTED" to px-pat-error
            exit paragraph
        end-if
    end-perform.
initialize-states.
    move 0 to anchored-start
    if px-pat-pattern-length > 0
        if px-pat-pattern(1:1) = "^" move 1 to anchored-start end-if
    end-if
    perform varying atom-index from 1 by 1
        until atom-index > px-pat-text-length + 1
        if anchored-start = 1
            move 0 to states(atom-index)
        else
            move 1 to states(atom-index)
        end-if
    end-perform
    if anchored-start = 1 move 1 to states(1) end-if.
clear-allowed.
    perform varying atom-index from 1 by 1
        until atom-index > 256
        move 0 to allowed(atom-index)
    end-perform.
advance-states.
    perform varying atom-index from 1 by 1
        until atom-index > px-pat-text-length + 1
        move 0 to next-states(atom-index)
        if optional-atom = 1
            move states(atom-index) to next-states(atom-index)
        end-if
    end-perform
    perform varying position-number from 1 by 1
        until position-number > px-pat-text-length
        compute code-value = function ord(
            px-pat-text(position-number:1)) - 1
        if allowed(code-value + 1) = 1
            if states(position-number) = 1
                move 1 to next-states(position-number + 1)
            end-if
            if repeated-atom = 1
                if next-states(position-number) = 1
                    move 1 to next-states(position-number + 1)
                end-if
            end-if
        end-if
    end-perform
    perform varying atom-index from 1 by 1
        until atom-index > px-pat-text-length + 1
        move next-states(atom-index) to states(atom-index)
    end-perform.
end program praxo-pattern-check.
