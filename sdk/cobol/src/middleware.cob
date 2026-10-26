       >>source format free
identification division.
program-id. praxo-middleware recursive.
environment division.
configuration section.
repository. function all intrinsic.
data division.
working-storage section.
01 limit-run-count binary-long value 0.
01 limit-runs occurs 32 times.
   05 limit-run-id pic x(128).
   05 limit-model-count pic s9(15) comp-3.
   05 limit-tool-count pic s9(15) comp-3.
local-storage section.
copy "json.cpy".
copy "schema.cpy".
01 redact-input pic x(32768).
01 redact-input-length binary-long.
01 redact-output pic x(32768).
01 redact-output-length binary-long.
01 output-pointer binary-long.
01 cursor-index binary-long.
01 at-index binary-long.
01 local-start binary-long.
01 domain-end binary-long.
01 dot-index binary-long.
01 suffix-index binary-long.
01 scan-index binary-long.
01 redact-scan binary-long.
01 email-ok pic 9.
01 run-index binary-long.
01 run-length binary-long.
01 char-index pic x.
01 copy-length binary-long.
01 dot-min binary-long.
01 suffix-length binary-long.
01 selected-index binary-long.
01 tool-index binary-long.
01 matches pic 9.
01 validation-ok pic 9.
01 advertised-count binary-long.
linkage section.
copy "middleware.cpy".
procedure division using px-middleware-request px-middleware-result.
    initialize px-middleware-result
    evaluate px-mw-op
        when "pii" perform redact-text
        when "pii-json" perform redact-json
        when "structured" perform structured-output
        when "call-limit" perform call-limit
        when "tool-selection" perform tool-selection
        when "fallback" perform fallback-output
        when other move "INVALID_REQUEST" to px-mw-error
    end-evaluate
    goback.
redact-text.
    if px-mw-text-length < 0 or > 32768
        move "INVALID_REQUEST" to px-mw-error
        exit paragraph
    end-if
    move px-mw-text(1:px-mw-text-length) to redact-input
    move px-mw-text-length to redact-input-length
    perform redact-email
    move redact-output(1:redact-output-length) to px-mw-result
    move redact-output-length to px-mw-result-length
    move 1 to px-mw-ok.
redact-json.
    if px-mw-text-length < 1 or > 32768
        move "INVALID_REQUEST" to px-mw-error
        exit paragraph
    end-if
    move px-mw-text(1:px-mw-text-length) to px-json-text
    move px-mw-text-length to px-json-length
    call "praxo-json-parse" using px-json-input px-json-document
        px-json-error
    if px-json-error not = spaces
        move px-json-error to px-mw-error
        exit paragraph
    end-if
    perform varying scan-index from 1 by 1
        until scan-index > px-json-count
        if px-json-kind(scan-index) = "S"
            move px-json-value(scan-index) to redact-input
            move px-json-value-length(scan-index)
                to redact-input-length
            perform redact-email
            move redact-output(1:redact-output-length)
                to px-json-value(scan-index)
            move redact-output-length
                to px-json-value-length(scan-index)
        end-if
    end-perform
    call "praxo-json-generate" using px-json-document px-json-output
        px-json-error
    if px-json-error not = spaces
        move px-json-error to px-mw-error
        exit paragraph
    end-if
    move px-output-text(1:px-output-length) to px-mw-result
    move px-output-length to px-mw-result-length
    move 1 to px-mw-ok.
structured-output.
    if px-mw-schema-length < 1 or > 32768
        or px-mw-output-length < 1 or > 32768
        or px-mw-max-repairs < 0
        move "INVALID_REQUEST" to px-mw-error
        exit paragraph
    end-if
    move 0 to validation-ok
    perform validate-output
    if validation-ok = 1
        move px-mw-output(1:px-mw-output-length) to px-mw-result
        move px-mw-output-length to px-mw-result-length
        move 1 to px-mw-ok
        exit paragraph
    end-if
    if px-mw-max-repairs > 0 and px-mw-repair-length > 0
        move px-mw-repair(1:px-mw-repair-length) to px-mw-output
        move px-mw-repair-length to px-mw-output-length
        perform validate-output
        if validation-ok = 1
            move px-mw-output(1:px-mw-output-length)
                to px-mw-result
            move px-mw-output-length to px-mw-result-length
            move 1 to px-mw-ok
            exit paragraph
        end-if
    end-if
    move "AGENT_STRUCTURED_OUTPUT" to px-mw-error.
validate-output.
    move px-mw-schema(1:px-mw-schema-length) to px-sch-schema
    move px-mw-schema-length to px-sch-schema-length
    move px-mw-output(1:px-mw-output-length) to px-sch-data
    move px-mw-output-length to px-sch-data-length
    call "praxo-jsonschema" using px-schema-request px-schema-result
    if px-sch-error = spaces and px-sch-error-count = 0
        move 1 to validation-ok
    end-if.
call-limit.
    move 0 to run-index
    compute run-length = function length(function trim(
        px-mw-run trailing))
    perform varying scan-index from 1 by 1
        until scan-index > limit-run-count
        if function length(function trim(
            limit-run-id(scan-index) trailing)) = run-length
            and limit-run-id(scan-index)(1:run-length)
                = px-mw-run(1:run-length)
            move scan-index to run-index
        end-if
    end-perform
    if run-index = 0
        if limit-run-count >= 32
            move "MIDDLEWARE_CAPACITY" to px-mw-error
            exit paragraph
        end-if
        add 1 to limit-run-count
        move limit-run-count to run-index
        move px-mw-run to limit-run-id(run-index)
    end-if
    evaluate px-mw-kind
        when "model"
            if px-mw-model-limit > 0
                and limit-model-count(run-index) >= px-mw-model-limit
                move "AGENT_MODEL_CALL_LIMIT" to px-mw-error
                exit paragraph
            end-if
            add 1 to limit-model-count(run-index)
        when "tool"
            if px-mw-tool-limit > 0
                and limit-tool-count(run-index) >= px-mw-tool-limit
                move "AGENT_TOOL_CALL_LIMIT" to px-mw-error
                exit paragraph
            end-if
            add 1 to limit-tool-count(run-index)
        when other
            move "INVALID_REQUEST" to px-mw-error
            exit paragraph
    end-evaluate
    move 1 to px-mw-ok.
tool-selection.
    move 0 to advertised-count
    if px-mw-selected-count < 0 or > 32
        or px-mw-tool-count < 0 or > 32
        move "INVALID_REQUEST" to px-mw-error
        exit paragraph
    end-if
    perform varying tool-index from 1 by 1
        until tool-index > px-mw-tool-count
        move 0 to matches
        perform varying selected-index from 1 by 1
            until selected-index > px-mw-selected-count
            if px-mw-selected(selected-index)
                = px-mw-tools(tool-index)
                move 1 to matches
            end-if
        end-perform
        if matches = 1
            add 1 to advertised-count
            move px-mw-tools(tool-index)
                to px-mw-advertised(advertised-count)
        end-if
    end-perform
    move advertised-count to px-mw-advertised-count
    if px-mw-requested-length < 1 or > 64
        move "INVALID_REQUEST" to px-mw-error
        exit paragraph
    end-if
    move 0 to matches
    perform varying selected-index from 1 by 1
        until selected-index > px-mw-selected-count
        if px-mw-selected(selected-index)(
            1:px-mw-requested-length)
            = px-mw-requested(1:px-mw-requested-length)
            move 1 to matches
        end-if
    end-perform
    if matches = 0
        move "AGENT_TOOL_NOT_SELECTED" to px-mw-error
        exit paragraph
    end-if
    move 1 to px-mw-ok.
fallback-output.
    if px-mw-fallback-length < 0 or > 2048
        move "INVALID_REQUEST" to px-mw-error
        exit paragraph
    end-if
    move px-mw-fallback(1:px-mw-fallback-length) to px-mw-result
    move px-mw-fallback-length to px-mw-result-length
    move 1 to px-mw-ok.
redact-email.
    move spaces to redact-output
    move 1 to output-pointer
    move 1 to cursor-index
    perform until cursor-index > redact-input-length
        move 0 to at-index
        perform varying redact-scan from cursor-index by 1
            until redact-scan > redact-input-length
            if redact-input(redact-scan:1) = "@"
                move redact-scan to at-index
                exit perform
            end-if
        end-perform
        if at-index = 0
            compute at-index = redact-input-length + 1
            perform copy-range
            exit perform
        end-if
        move at-index to local-start
        perform until local-start <= cursor-index
            if local-start <= 1 exit perform end-if
            move redact-input(local-start - 1:1) to char-index
            perform local-character
            if matches = 0 exit perform end-if
            subtract 1 from local-start
        end-perform
        move at-index to domain-end
        add 1 to domain-end
        perform until domain-end > redact-input-length
            move redact-input(domain-end:1) to char-index
            perform domain-character
            if matches = 0 exit perform end-if
            add 1 to domain-end
        end-perform
        move 0 to dot-index
        compute redact-scan = at-index
        perform until redact-scan >= domain-end
            add 1 to redact-scan
            if redact-scan >= domain-end exit perform end-if
            if redact-input(redact-scan:1) = "."
                move redact-scan to dot-index
            end-if
        end-perform
        compute dot-min = at-index + 1
        move 0 to email-ok
        if local-start < at-index and dot-index > dot-min
            move dot-index to suffix-index
            add 1 to suffix-index
            perform until suffix-index >= domain-end
                move redact-input(suffix-index:1) to char-index
                perform letter-character
                if matches = 0 exit perform end-if
                add 1 to suffix-index
            end-perform
            compute suffix-length = domain-end - dot-index - 1
            if suffix-index = domain-end and suffix-length >= 2
                move 1 to email-ok
            end-if
        end-if
        if email-ok = 1
            if local-start > cursor-index
                compute redact-scan = local-start - 1
                perform copy-through
            end-if
            string "[REDACTED:email]" delimited by size
                into redact-output with pointer output-pointer
            end-string
            move domain-end to cursor-index
        else
            move at-index to redact-scan
            perform copy-through
            add 1 to cursor-index
        end-if
    end-perform
    compute redact-output-length = output-pointer - 1.
copy-range.
    move redact-input-length to redact-scan
    perform copy-through
    compute cursor-index = redact-input-length + 1.
copy-through.
    if redact-scan < cursor-index exit paragraph end-if
    compute redact-scan = redact-scan - cursor-index + 1
    string redact-input(cursor-index:redact-scan) delimited by size
        into redact-output with pointer output-pointer
    end-string.
local-character.
    if char-index >= "A" and <= "Z"
        move 1 to matches
        exit paragraph
    end-if
    if char-index >= "a" and <= "z"
        move 1 to matches
        exit paragraph
    end-if
    if char-index >= "0" and <= "9"
        move 1 to matches
        exit paragraph
    end-if
    if char-index = "." or "_" or "%" or "+" or "-"
        move 1 to matches
        exit paragraph
    end-if
    move 0 to matches.
domain-character.
    if char-index >= "A" and <= "Z"
        move 1 to matches
        exit paragraph
    end-if
    if char-index >= "a" and <= "z"
        move 1 to matches
        exit paragraph
    end-if
    if char-index >= "0" and <= "9"
        move 1 to matches
        exit paragraph
    end-if
    if char-index = "." or "-"
        move 1 to matches
        exit paragraph
    end-if
    move 0 to matches.
letter-character.
    if char-index >= "A" and <= "Z"
        move 1 to matches
        exit paragraph
    end-if
    if char-index >= "a" and <= "z"
        move 1 to matches
        exit paragraph
    end-if
    move 0 to matches.
end program praxo-middleware.
