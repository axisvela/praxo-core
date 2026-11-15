       >>source format free
identification division.
program-id. consumer-example.
environment division.
configuration section.
repository. function all intrinsic.
data division.
working-storage section.
copy "api.cpy".
copy "consumer-state.cpy".
01 ws-count pic zzz9.
procedure division.
    initialize px-options px-session px-prompt px-result
    initialize consumer-state
    move "consumer-model" to px-model-program
    move "consumer-tool" to px-tool-program
    move "consumer-policy" to px-policy-program
    move 1 to px-allowed-tool-count
    move "record" to px-allowed-tools(1)
    move 3 to px-max-steps
    move "Record the requested target." to px-prompt-text
    compute px-prompt-length = function length(
        function trim(px-prompt-text trailing))
    move "public" to cs-target

    call "praxo-run" using px-options px-session px-prompt
        px-result px-user-data
    if px-result-error not = spaces
        or px-result-output(1:px-result-length) not = "recorded"
        or cs-effects not = 1
        display "allow failed: " function trim(px-result-error)
        stop run returning 1
    end-if
    move cs-effects to ws-count
    display "allow: recorded; effects=" function trim(ws-count)

    initialize px-session px-result consumer-state
    move "Record the requested target." to px-prompt-text
    compute px-prompt-length = function length(
        function trim(px-prompt-text trailing))
    move "private" to cs-target
    call "praxo-run" using px-options px-session px-prompt
        px-result px-user-data
    if px-result-error = spaces or cs-effects not = 0
        display "deny failed: effects=" function trim(cs-effects)
        stop run returning 1
    end-if
    move cs-effects to ws-count
    display "deny: policy rejected; effects=" function trim(ws-count)

    stop run.
end program consumer-example.

identification division.
program-id. consumer-model recursive.
data division.
linkage section.
copy "api.cpy".
copy "consumer-state.cpy".
procedure division using px-session px-response px-user-data px-status.
    add 1 to cs-model-count
    if cs-model-count = 1
        move spaces to px-answer
        move 0 to px-answer-length
        move 1 to px-call-count
        move "record-1" to px-call-id(1)
        move "record" to px-call-name(1)
        string '{"target":"' function trim(cs-target) '"}'
            into px-call-input(1)
        compute px-call-input-length(1) = function length(
            function trim(px-call-input(1) trailing))
    else
        move "recorded" to px-answer
        move 8 to px-answer-length
        move 0 to px-call-count
    end-if
    goback.
end program consumer-model.

identification division.
program-id. consumer-tool recursive.
data division.
linkage section.
copy "api.cpy".
copy "consumer-state.cpy".
procedure division using px-call px-tool-result px-user-data px-status.
    add 1 to cs-effects
    move px-tool-input to px-tool-output
    move px-tool-input-length to px-tool-output-length
    goback.
end program consumer-tool.

identification division.
program-id. consumer-policy recursive.
data division.
working-storage section.
01 ws-found pic 9(4).
linkage section.
copy "api.cpy".
copy "consumer-state.cpy".
procedure division using px-action px-user-data px-status.
    if px-action-kind = "tool.invoke"
        if px-action-tool not = "record"
            move "AGENT_POLICY_DENIED" to px-status
        else
            move 0 to ws-found
            inspect px-action-input tallying ws-found
                for all '"target":"public"'
            if ws-found = 0
                move "AGENT_POLICY_DENIED" to px-status
            end-if
        end-if
    end-if
    goback.
end program consumer-policy.
