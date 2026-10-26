       >>source format free
identification division.
program-id. praxo-run recursive.
environment division.
configuration section.
repository. function all intrinsic.
data division.
local-storage section.
copy "callbacks.cpy".
01 work-session.
   copy "history.cpy".
01 step-limit binary-long.
01 step-number binary-long.
01 call-number binary-long.
01 message-number binary-long.
01 token-total pic 9(17) comp-3.
01 event-status pic x(64).
linkage section.
copy "inputs.cpy".
procedure division using px-options px-session px-prompt
    px-result px-user-data.
    initialize px-result
    move px-session to work-session
    if px-message-count of work-session < 0 or > 63
        move "AGENT_CONTEXT_BUDGET" to px-result-error
        goback
    end-if
    if px-prompt-length < 0 or > 2048
        move "INVALID_REQUEST" to px-result-error
        goback
    end-if
    perform varying message-number from 1 by 1
        until message-number > px-message-count of work-session
        if px-content-length of work-session(message-number)
            < 0 or > 2048
            move "INVALID_REQUEST" to px-result-error
            goback
        end-if
    end-perform
    move px-max-steps to step-limit
    if step-limit <= 0 move 8 to step-limit end-if
    add 1 to px-message-count of work-session
    move px-message-count of work-session to message-number
    initialize px-messages of work-session(message-number)
    move "user" to px-role of work-session(message-number)
    move px-prompt-text to px-content of work-session(message-number)
    move px-prompt-length
        to px-content-length of work-session(message-number)
    initialize px-event
    move "run.started" to px-event-kind
    perform emit-event
    perform varying step-number from 1 by 1
        until step-number > step-limit or px-result-error not = spaces
        initialize px-action
        move "model.generate" to px-action-kind
        perform authorize-action
        if px-result-error not = spaces exit perform end-if
        initialize px-response px-status
        call px-model-program using work-session px-response
            px-user-data px-status
            on exception move "MODEL_ERROR" to px-status
        end-call
        if px-status not = spaces
            move px-status to px-result-error
            exit perform
        end-if
        move step-number to px-result-steps
        if px-answer-length < 0 or > 2048
            or px-call-count < 0 or > 8
            or px-input-tokens < 0 or px-output-tokens < 0
            move "INVALID_REQUEST" to px-result-error
            exit perform
        end-if
        perform varying call-number from 1 by 1
            until call-number > px-call-count
            if px-call-input-length(call-number) < 0 or > 2048
                or px-call-name(call-number) = spaces
                move "INVALID_REQUEST" to px-result-error
            end-if
        end-perform
        if px-result-error not = spaces exit perform end-if
        add px-input-tokens to px-result-input-tokens
            on size error
                move "AGENT_MAX_TOKENS" to px-result-error
        end-add
        add px-output-tokens to px-result-output-tokens
            on size error
                move "AGENT_MAX_TOKENS" to px-result-error
        end-add
        compute token-total = px-result-input-tokens
            + px-result-output-tokens
        if px-max-tokens > 0 and token-total > px-max-tokens
            move "AGENT_MAX_TOKENS" to px-result-error
        end-if
        if px-result-error not = spaces exit perform end-if
        if px-call-count = 0
            move px-answer to px-result-output
            move px-answer-length to px-result-length
            initialize px-event
            move "run.completed" to px-event-kind
            perform emit-event
            goback
        end-if
        if px-message-count of work-session + 1 + px-call-count > 64
            move "AGENT_CONTEXT_BUDGET" to px-result-error
            exit perform
        end-if
        add 1 to px-message-count of work-session
        move px-message-count of work-session to message-number
        initialize px-messages of work-session(message-number)
        move "assistant" to px-role of work-session(message-number)
        move px-answer to px-content of work-session(message-number)
        move px-answer-length
            to px-content-length of work-session(message-number)
        perform varying call-number from 1 by 1
            until call-number > px-call-count
                or px-result-error not = spaces
            move px-calls(call-number) to px-call
            perform invoke-tool
        end-perform
    end-perform
    if px-result-error = spaces
        move "AGENT_MAX_STEPS" to px-result-error
    end-if
    initialize px-event
    move "run.failed" to px-event-kind
    perform emit-event
    goback.

authorize-action.
    if px-policy-program = spaces exit paragraph end-if
    initialize px-status
    call px-policy-program using px-action px-user-data px-status
        on exception move "POLICY_ERROR" to px-status
    end-call
    if px-status not = spaces
        move "POLICY_ERROR" to px-result-error
    end-if.

invoke-tool.
    initialize px-action
    move "tool.invoke" to px-action-kind
    move px-tool-name to px-action-tool
    move px-tool-input to px-action-input
    move px-tool-input-length to px-action-input-length
    perform authorize-action
    if px-result-error not = spaces exit paragraph end-if
    if px-tool-program = spaces
        move "TOOL_NOT_FOUND" to px-result-error
        exit paragraph
    end-if
    initialize px-event
    move "tool.call" to px-event-kind
    move px-tool-name to px-event-tool
    perform emit-event
    initialize px-tool-result px-status
    call px-tool-program using px-call px-tool-result
        px-user-data px-status
        on exception move "TOOL_NOT_FOUND" to px-status
    end-call
    if px-status not = spaces
        move px-status to px-result-error
        exit paragraph
    end-if
    if px-tool-output-length < 0 or > 2048
        move "INVALID_REQUEST" to px-result-error
        exit paragraph
    end-if
    add 1 to px-message-count of work-session
    move px-message-count of work-session to message-number
    initialize px-messages of work-session(message-number)
    move "tool" to px-role of work-session(message-number)
    move px-tool-output to px-content of work-session(message-number)
    move px-tool-output-length
        to px-content-length of work-session(message-number)
    move px-tool-id
        to px-message-call-id of work-session(message-number).

emit-event.
    if px-event-program = spaces exit paragraph end-if
    move spaces to event-status
    call px-event-program using px-event px-user-data event-status
        on exception continue
    end-call.
end program praxo-run.
