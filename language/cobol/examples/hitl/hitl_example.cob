       >>source format free
identification division.
program-id. hitl-example.
environment division.
configuration section.
repository. function all intrinsic.
data division.
working-storage section.
copy "api.cpy".
copy "hitl-state.cpy".
01 ws-count pic zzz9.
procedure division.
    initialize px-options px-session px-prompt px-result
    initialize hitl-state
    move "write-model" to px-model-program
    move "write-tool" to px-tool-program
    move "write-policy" to px-policy-program
    move "write-interrupt" to px-interrupt-program
    move 1 to px-interrupt-count
    move "write_note" to px-interrupt-tools(1)
    move 4 to px-max-steps
    move "write" to px-prompt-text
    move 5 to px-prompt-length

    call "praxo-run" using px-options px-session px-prompt
        px-result px-user-data
    if px-result-error not = spaces or hs-effects not = 1
        display "approve failed: " function trim(px-result-error)
        stop run returning 1
    end-if
    move hs-effects to ws-count
    display "approve: written; effects=" function trim(ws-count)

    initialize px-session px-result
    initialize hitl-state
    move 1 to hs-edit
    call "praxo-run" using px-options px-session px-prompt
        px-result px-user-data
    if px-result-error(1:12) not = "POLICY_ERROR"
        or hs-effects not = 0
        display "edit failed: " function trim(px-result-error)
        stop run returning 1
    end-if
    move hs-effects to ws-count
    display "edit: policy rejected; effects=" function trim(ws-count)

    stop run.
end program hitl-example.

identification division.
program-id. write-model recursive.
data division.
linkage section.
copy "api.cpy".
copy "hitl-state.cpy".
procedure division using px-session px-response px-user-data px-status.
    add 1 to hs-model-count
    if hs-model-count = 1
        move spaces to px-answer
        move 0 to px-answer-length
        move 1 to px-call-count
        move "call-1" to px-call-id(1)
        move "write_note" to px-call-name(1)
        move '{"text":"hello","visibility":"public"}'
            to px-call-input(1)
        compute px-call-input-length(1) = function length(
            function trim(px-call-input(1) trailing))
    else
        move "done" to px-answer
        move 4 to px-answer-length
        move 0 to px-call-count
    end-if
    goback.
end program write-model.

identification division.
program-id. write-tool recursive.
data division.
linkage section.
copy "api.cpy".
copy "hitl-state.cpy".
procedure division using px-call px-tool-result px-user-data px-status.
    add 1 to hs-effects
    move px-tool-input to px-tool-output
    move px-tool-input-length to px-tool-output-length
    goback.
end program write-tool.

identification division.
program-id. write-policy recursive.
data division.
working-storage section.
01 ws-found pic 9(4).
linkage section.
copy "api.cpy".
copy "hitl-state.cpy".
procedure division using px-action px-user-data px-status.
    if px-action-kind = "tool.invoke"
        add 1 to hs-policy-count
        if px-action-tool not = "write_note"
            move "AGENT_POLICY_DENIED" to px-status
        else
            move 0 to ws-found
            inspect px-action-input tallying ws-found
                for all '"visibility":"private"'
            if ws-found > 0
                move "AGENT_POLICY_DENIED" to px-status
            end-if
        end-if
    end-if
    goback.
end program write-policy.

identification division.
program-id. write-interrupt recursive.
data division.
linkage section.
copy "api.cpy".
copy "hitl-state.cpy".
copy "interrupt.cpy".
procedure division using px-call px-interrupt px-user-data px-status.
    if hs-edit = 1
        move "edit" to px-interrupt-action
        move '{"text":"hello","visibility":"private"}'
            to px-interrupt-input
        compute px-interrupt-input-length = function length(
            function trim(px-interrupt-input trailing))
    else
        move "approve" to px-interrupt-action
    end-if
    goback.
end program write-interrupt.
