       >>source format free
identification division.
program-id. praxo-agent-vector recursive.
data division.
local-storage section.
copy "api.cpy".
copy "vector-context.cpy".
linkage section.
copy "agent-vector.cpy".
procedure division using px-agent-vector-request px-agent-vector-result.
    initialize px-agent-vector-result
    if px-av-script-count < 0 or > 16
        or px-av-tool-count < 0 or > 16
        move "INVALID_REQUEST" to px-av-error
        goback
    end-if
    initialize px-options px-session px-prompt
    set vector-input to address of px-agent-vector-request
    set vector-output to address of px-agent-vector-result
    move 0 to vector-step
    move "vector-model" to px-model-program
    move "vector-tool" to px-tool-program
    move "vector-events" to px-event-program
    move px-av-max-steps to px-max-steps
    move px-av-max-tokens to px-max-tokens
    move px-av-prompt to px-prompt-text
    move px-av-prompt-length to px-prompt-length
    call "praxo-run" using px-options px-session px-prompt
        px-result px-user-data
    move px-result-output to px-av-result-output
    move px-result-length to px-av-result-output-length
    move px-result-steps to px-av-steps
    move px-result-error to px-av-error
    goback.
end program praxo-agent-vector.

identification division.
program-id. vector-model recursive.
data division.
local-storage section.
01 call-index binary-long.
linkage section.
copy "api.cpy".
copy "vector-context.cpy".
copy "agent-vector.cpy".
procedure division using px-session px-response px-user-data px-status.
    set address of px-agent-vector-request to vector-input
    add 1 to vector-step
    if vector-step > px-av-script-count
        move "AGENT_SCRIPT_EXHAUSTED" to px-status
        goback
    end-if
    move px-av-content(vector-step) to px-answer
    move px-av-content-length(vector-step) to px-answer-length
    move px-av-input-tokens(vector-step) to px-input-tokens
    move px-av-output-tokens(vector-step) to px-output-tokens
    move px-av-call-count(vector-step) to px-call-count
    if px-call-count < 0 or > 8 goback end-if
    perform varying call-index from 1 by 1 until call-index > px-call-count
        move "c1" to px-call-id(call-index)
        move px-av-call-name(vector-step, call-index)
            to px-call-name(call-index)
        move px-av-call-args(vector-step, call-index)
            to px-call-input(call-index)
        move px-av-call-args-length(vector-step, call-index)
            to px-call-input-length(call-index)
    end-perform
    goback.
end program vector-model.

identification division.
program-id. vector-tool recursive.
data division.
local-storage section.
01 tool-index binary-long.
linkage section.
copy "api.cpy".
copy "vector-context.cpy".
copy "agent-vector.cpy".
procedure division using px-call px-tool-result px-user-data px-status.
    set address of px-agent-vector-request to vector-input
    set address of px-agent-vector-result to vector-output
    perform varying tool-index from 1 by 1
        until tool-index > px-av-tool-count
        if px-tool-name = px-av-tools(tool-index)
            add 1 to px-av-invocations
            move px-tool-input to px-tool-output
            move px-tool-input-length to px-tool-output-length
            goback
        end-if
    end-perform
    move "TOOL_NOT_FOUND" to px-status
    goback.
end program vector-tool.

identification division.
program-id. vector-events recursive.
data division.
linkage section.
copy "api.cpy".
copy "vector-context.cpy".
copy "agent-vector.cpy".
procedure division using px-event px-user-data px-status.
    set address of px-agent-vector-result to vector-output
    if px-av-event-count >= 64
        move "EVENT_CAPACITY" to px-status
        goback
    end-if
    add 1 to px-av-event-count
    move px-event-kind to px-av-events(px-av-event-count)
    goback.
end program vector-events.
