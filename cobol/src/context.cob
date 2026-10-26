       >>source format free
identification division.
program-id. praxo-context recursive.
environment division.
configuration section.
repository. function all intrinsic.
data division.
local-storage section.
01 token-total pic s9(15) comp-3.
01 index-number binary-long.
01 system-count binary-long.
01 rest-count binary-long.
01 keep-count binary-long.
01 first-kept binary-long.
01 omitted-count binary-long.
01 output-count binary-long.
01 system-index binary-long.
01 rest-index binary-long.
01 system-tokens pic s9(15) comp-3.
01 output-tokens pic s9(15) comp-3.
01 available-tokens pic s9(15) comp-3.
01 byte-limit binary-long.
01 marker-digits pic z(9)9.
01 truncated pic x(2048).
01 truncated-length binary-long.
01 skip-message pic 9.
01 work-messages occurs 64 times.
   05 work-role pic x(16).
   05 work-content pic x(2048).
   05 work-content-length binary-long.
01 rest-messages occurs 64 times.
   05 rest-role pic x(16).
   05 rest-content pic x(2048).
   05 rest-content-length binary-long.
linkage section.
copy "context.cpy".
procedure division using px-context-request px-context-result.
    initialize px-context-result
    if px-ctx-count < 0 or > 64
        move "INVALID_REQUEST" to px-ctx-error
        goback
    end-if
    perform varying index-number from 1 by 1
        until index-number > px-ctx-count
        if px-ctx-content-length(index-number) < 0
            or > 2048
            move "INVALID_REQUEST" to px-ctx-error
            goback
        end-if
    end-perform
    perform estimate-tokens
    if px-ctx-op = "estimate"
        move token-total to px-ctx-tokens
        goback
    end-if
    if px-ctx-op not = "compact"
        move "INVALID_REQUEST" to px-ctx-error
        goback
    end-if
    move 1 to px-ctx-ok
    perform copy-input
    if px-ctx-max-tokens <= 0
        or token-total <= px-ctx-max-tokens
        move token-total to px-ctx-tokens
        move output-count to px-ctx-out-count
        goback
    end-if
    perform split-messages
    perform check-system
    if px-ctx-ok not = 1
        move 0 to px-ctx-out-count
        goback
    end-if
    move px-ctx-keep-recent to keep-count
    if keep-count <= 0 move 4 to keep-count end-if
    compute first-kept = rest-count - keep-count + 1
    if first-kept < 1 move 1 to first-kept end-if
    perform until first-kept <= 1
        if rest-role(first-kept) not = "tool" exit perform end-if
        subtract 1 from first-kept
    end-perform
    compute omitted-count = first-kept - 1
    perform build-output
    perform until output-tokens <= px-ctx-max-tokens
        or rest-count - first-kept + 1 <= 1
        if rest-role(first-kept + 1) = "tool" exit perform end-if
        add 1 to first-kept
        perform build-output
    end-perform
    if output-tokens > px-ctx-max-tokens
        move 0 to px-ctx-ok px-ctx-out-count
    else
        move output-count to px-ctx-out-count
        move output-tokens to px-ctx-tokens
    end-if
    goback.
estimate-tokens.
    move 0 to token-total
    perform varying index-number from 1 by 1
        until index-number > px-ctx-count
        compute token-total = token-total + 4
            + px-ctx-content-length(index-number) / 4
    end-perform.
copy-input.
    move px-ctx-count to output-count
    perform varying index-number from 1 by 1
        until index-number > px-ctx-count
        move px-ctx-role(index-number) to px-ctx-out-role(index-number)
        move px-ctx-content(index-number)
            to px-ctx-out-content(index-number)
        move px-ctx-content-length(index-number)
            to px-ctx-out-content-length(index-number)
    end-perform.
split-messages.
    move 0 to system-count rest-count
    perform varying index-number from 1 by 1
        until index-number > px-ctx-count
        move 0 to skip-message
        if px-ctx-role(index-number) = "system"
            and px-ctx-content-length(index-number) >= 19
            and px-ctx-content(index-number)(1:19)
                = "[context compacted:"
            move 1 to skip-message
        end-if
        if skip-message = 0
          if px-ctx-role(index-number) = "system"
            add 1 to system-count
            move px-ctx-role(index-number)
                to work-role(system-count)
            move px-ctx-content(index-number)
                to work-content(system-count)
            move px-ctx-content-length(index-number)
                to work-content-length(system-count)
        else
            add 1 to rest-count
            move px-ctx-role(index-number)
                to rest-role(rest-count)
            move px-ctx-content(index-number)
                to rest-content(rest-count)
            move px-ctx-content-length(index-number)
                to rest-content-length(rest-count)
          end-if
        end-if
    end-perform.
check-system.
    move 0 to system-tokens
    perform varying system-index from 1 by 1
        until system-index > system-count
        compute system-tokens = system-tokens + 4
            + work-content-length(system-index) / 4
    end-perform
    if system-tokens <= px-ctx-max-tokens exit paragraph end-if
    if system-count = 0
        move 0 to px-ctx-ok
        exit paragraph
    end-if
    move 1 to system-count
    compute available-tokens = px-ctx-max-tokens - 4
    if available-tokens < 0 move 0 to available-tokens end-if
    compute byte-limit = available-tokens * 4
    if byte-limit < work-content-length(1)
        if byte-limit <= 0
            move spaces to truncated
            move 0 to truncated-length
        else
            if byte-limit <= 16
                move work-content(1)(1:byte-limit) to truncated
                move byte-limit to truncated-length
            else
                compute truncated-length = byte-limit - 16
                move work-content(1)(1:truncated-length) to truncated
                move x"0a" to truncated(truncated-length + 1:1)
                move "[truncated]" to truncated(truncated-length + 2:11)
                compute truncated-length = truncated-length + 12
            end-if
        end-if
        move truncated to work-content(1)
        move truncated-length to work-content-length(1)
    end-if
    compute system-tokens = 4 + work-content-length(1) / 4
    if system-tokens > px-ctx-max-tokens move 0 to px-ctx-ok end-if.
build-output.
    move 0 to output-count
    perform varying system-index from 1 by 1
        until system-index > system-count
        add 1 to output-count
        move work-role(system-index) to px-ctx-out-role(output-count)
        move work-content(system-index)
            to px-ctx-out-content(output-count)
        move work-content-length(system-index)
            to px-ctx-out-content-length(output-count)
    end-perform
    if omitted-count > 0
        add 1 to output-count
        move "system" to px-ctx-out-role(output-count)
        move spaces to px-ctx-out-content(output-count)
        move omitted-count to marker-digits
        string "[context compacted: " delimited by size
            function trim(marker-digits) delimited by size
            " older messages omitted]"
            delimited by size
            into px-ctx-out-content(output-count)
        end-string
        move function length(function trim(
            px-ctx-out-content(output-count) trailing))
            to px-ctx-out-content-length(output-count)
    end-if
    perform varying rest-index from first-kept by 1
        until rest-index > rest-count
        add 1 to output-count
        move rest-role(rest-index) to px-ctx-out-role(output-count)
        move rest-content(rest-index)
            to px-ctx-out-content(output-count)
        move rest-content-length(rest-index)
            to px-ctx-out-content-length(output-count)
    end-perform
    move 0 to output-tokens
    perform varying index-number from 1 by 1
        until index-number > output-count
        compute output-tokens = output-tokens + 4
            + px-ctx-out-content-length(index-number) / 4
    end-perform.
end program praxo-context.
