       >>source format free
identification division.
program-id. praxo-run recursive.
environment division.
configuration section.
repository. function all intrinsic.
data division.
local-storage section.
copy "callbacks.cpy".
copy "tool-batch.cpy".
01 work-session.
   copy "history.cpy".
01 step-limit binary-long.
01 entered-count binary-long.
01 allowed-index binary-long.
01 step-number binary-long.
01 call-number binary-long.
01 message-number binary-long.
01 token-total pic 9(17) comp-3.
01 event-status pic x(64).
01 stream-status pic x(64).
01 cleanup-status pic x(64).
01 first-cleanup-error pic x(64).
01 original-tool-name pic x(64).
01 original-tool-input pic x(2048).
01 original-tool-input-length binary-long.
01 tool-allowed-flag pic 9.
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
    if px-allowed-tool-count < 0 or > 8
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
    move 0 to entered-count
    perform before-run-hooks
    if px-result-error not = spaces
        perform after-run-hooks
        goback
    end-if
    perform check-cancelled
    if px-result-error not = spaces
        perform after-run-hooks
        goback
    end-if
    initialize px-event
    move "run.started" to px-event-kind
    perform emit-event
    initialize px-stream-part
    move "values" to px-stream-kind
    move 0 to px-stream-step
    move px-prompt-text to px-stream-data
    move px-prompt-length to px-stream-data-length
    perform emit-stream
    if px-result-error not = spaces
        perform after-run-hooks
        initialize px-event
        move "run.failed" to px-event-kind
        perform emit-event
        goback
    end-if
    perform varying step-number from 1 by 1
        until step-number > step-limit or px-result-error not = spaces
        perform check-cancelled
        if px-result-error not = spaces exit perform end-if
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
        perform check-cancelled
        if px-result-error not = spaces exit perform end-if
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
            initialize px-stream-part
            move "messages" to px-stream-kind
            move step-number to px-stream-step
            move px-answer to px-stream-data
            move px-answer-length to px-stream-data-length
            perform emit-stream
            perform after-run-hooks
            initialize px-event
            if px-result-error = spaces
                move "run.completed" to px-event-kind
            else
                move "run.failed" to px-event-kind
            end-if
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
        if px-tool-batch-program not = spaces
            perform invoke-tool-batch
        else
            perform varying call-number from 1 by 1
                until call-number > px-call-count
                    or px-result-error not = spaces
                move px-calls(call-number) to px-call
                perform check-cancelled
                if px-result-error not = spaces exit perform end-if
                perform invoke-tool
                perform check-cancelled
                if px-result-error not = spaces exit perform end-if
            end-perform
        end-if
    end-perform
    if px-result-error = spaces
        move "AGENT_MAX_STEPS" to px-result-error
    end-if
    perform after-run-hooks
    initialize px-event
    move "run.failed" to px-event-kind
    perform emit-event
    goback.

before-run-hooks.
    if px-before-run-program = spaces
        and px-after-run-program = spaces
        exit paragraph
    end-if
    add 1 to entered-count
    if px-before-run-program not = spaces
        perform call-before-run-1
        if px-result-error not = spaces exit paragraph end-if
    end-if
    if px-before-run-program-2 = spaces
        and px-after-run-program-2 = spaces
        exit paragraph
    end-if
    add 1 to entered-count
    if px-before-run-program-2 not = spaces
        perform call-before-run-2
    end-if.

call-before-run-1.
    initialize px-action
    move "run.before" to px-action-kind
    move spaces to px-status
    call px-before-run-program using px-action px-user-data px-status
        on exception move "MIDDLEWARE_ERROR" to px-status
    end-call
    if px-status not = spaces move px-status to px-result-error end-if.

call-before-run-2.
    initialize px-action
    move "run.before" to px-action-kind
    move spaces to px-status
    call px-before-run-program-2 using px-action px-user-data px-status
        on exception move "MIDDLEWARE_ERROR" to px-status
    end-call
    if px-status not = spaces move px-status to px-result-error end-if.

after-run-hooks.
    move spaces to first-cleanup-error
    if entered-count >= 1 and px-after-run-program not = spaces
        perform call-after-run-1
    end-if
    if entered-count >= 2 and px-after-run-program-2 not = spaces
        perform call-after-run-2
    end-if
    if px-result-error = spaces and first-cleanup-error not = spaces
        move first-cleanup-error to px-result-error
    end-if.

call-after-run-1.
    move spaces to cleanup-status
    call px-after-run-program using px-result px-user-data cleanup-status
        on exception move "MIDDLEWARE_ERROR" to cleanup-status
    end-call
    if cleanup-status not = spaces and first-cleanup-error = spaces
        move cleanup-status to first-cleanup-error
    end-if.

call-after-run-2.
    move spaces to cleanup-status
    call px-after-run-program-2 using px-result px-user-data cleanup-status
        on exception move "MIDDLEWARE_ERROR" to cleanup-status
    end-call
    if cleanup-status not = spaces and first-cleanup-error = spaces
        move cleanup-status to first-cleanup-error
    end-if.

before-tool-hooks.
    if px-before-tool-program = spaces exit paragraph end-if
    move spaces to px-status
    call px-before-tool-program using px-call px-user-data px-status
        on exception move "MIDDLEWARE_ERROR" to px-status
    end-call
    if px-status not = spaces move px-status to px-result-error end-if.

check-cancelled.
    if px-cancel-program = spaces exit paragraph end-if
    initialize px-action
    move "run.check" to px-action-kind
    move spaces to px-status
    call px-cancel-program using px-action px-user-data px-status
        on exception move "AGENT_CANCELLED" to px-status
    end-call
    if px-status not = spaces
        move "AGENT_CANCELLED" to px-result-error
    end-if.

check-tool-allowed.
    move 1 to tool-allowed-flag
    if px-allowed-tool-count <= 0 exit paragraph end-if
    move 0 to tool-allowed-flag
    perform varying allowed-index from 1 by 1
        until allowed-index > px-allowed-tool-count
        if px-allowed-tools(allowed-index) = px-tool-name
            move 1 to tool-allowed-flag
            exit perform
        end-if
    end-perform.

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
    perform check-tool-allowed
    if tool-allowed-flag = 0
        move "AGENT_TOOL_NOT_ALLOWED" to px-result-error
        exit paragraph
    end-if
    initialize px-action
    move "tool.invoke" to px-action-kind
    move px-tool-name to px-action-tool
    move px-tool-input to px-action-input
    move px-tool-input-length to px-action-input-length
    perform authorize-action
    if px-result-error not = spaces exit paragraph end-if
    move px-tool-name to original-tool-name
    move px-tool-input to original-tool-input
    move px-tool-input-length to original-tool-input-length
    perform before-tool-hooks
    if px-result-error not = spaces exit paragraph end-if
    if px-tool-name = spaces
        or px-tool-input-length < 0 or > 2048
        move "INVALID_REQUEST" to px-result-error
        exit paragraph
    end-if
    perform check-tool-allowed
    if tool-allowed-flag = 0
        move "AGENT_TOOL_NOT_ALLOWED" to px-result-error
        exit paragraph
    end-if
    if px-tool-name not = original-tool-name
        or px-tool-input not = original-tool-input
        or px-tool-input-length not = original-tool-input-length
        initialize px-action
        move "tool.invoke" to px-action-kind
        move px-tool-name to px-action-tool
        move px-tool-input to px-action-input
        move px-tool-input-length to px-action-input-length
        perform authorize-action
        if px-result-error not = spaces exit paragraph end-if
    end-if
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

prepare-batch-call.
    perform check-tool-allowed
    if tool-allowed-flag = 0
        move "AGENT_TOOL_NOT_ALLOWED" to px-result-error
        exit paragraph
    end-if
    initialize px-action
    move "tool.invoke" to px-action-kind
    move px-tool-name to px-action-tool
    move px-tool-input to px-action-input
    move px-tool-input-length to px-action-input-length
    perform authorize-action
    if px-result-error not = spaces exit paragraph end-if
    move px-tool-name to original-tool-name
    move px-tool-input to original-tool-input
    move px-tool-input-length to original-tool-input-length
    perform before-tool-hooks
    if px-result-error not = spaces exit paragraph end-if
    if px-tool-name = spaces
        or px-tool-input-length < 0 or > 2048
        move "INVALID_REQUEST" to px-result-error
        exit paragraph
    end-if
    perform check-tool-allowed
    if tool-allowed-flag = 0
        move "AGENT_TOOL_NOT_ALLOWED" to px-result-error
        exit paragraph
    end-if
    if px-tool-name not = original-tool-name
        or px-tool-input not = original-tool-input
        or px-tool-input-length not = original-tool-input-length
        initialize px-action
        move "tool.invoke" to px-action-kind
        move px-tool-name to px-action-tool
        move px-tool-input to px-action-input
        move px-tool-input-length to px-action-input-length
        perform authorize-action
    end-if.

invoke-tool-batch.
    initialize px-tool-batch-request px-tool-batch-result
    move px-call-count to px-tb-count
    move px-max-parallel-tools to px-tb-max-parallel
    if px-tb-max-parallel <= 0 move 1 to px-tb-max-parallel end-if
    perform varying call-number from 1 by 1
        until call-number > px-call-count
            or px-result-error not = spaces
        move px-calls(call-number) to px-call
        perform check-cancelled
        if px-result-error not = spaces exit perform end-if
        perform prepare-batch-call
        if px-result-error not = spaces exit perform end-if
        move px-tool-id to px-tb-call-id(call-number)
        move px-tool-name to px-tb-call-name(call-number)
        move px-tool-input to px-tb-call-input(call-number)
        move px-tool-input-length
            to px-tb-call-input-length(call-number)
        initialize px-event
        move "tool.call" to px-event-kind
        move px-tool-name to px-event-tool
        perform emit-event
    end-perform
    if px-result-error not = spaces exit paragraph end-if
    move spaces to px-tool-batch-status
    call px-tool-batch-program using px-tool-batch-request
        px-tool-batch-result px-user-data px-tool-batch-status
        on exception move "TOOL_NOT_FOUND" to px-tool-batch-status
    end-call
    if px-tool-batch-status not = spaces
        move px-tool-batch-status to px-result-error
        exit paragraph
    end-if
    if px-tb-result-count not = px-tb-count
        move "INVALID_REQUEST" to px-result-error
        exit paragraph
    end-if
    perform varying call-number from 1 by 1
        until call-number > px-tb-count
            or px-result-error not = spaces
        if px-tb-result-id(call-number) not = px-tb-call-id(call-number)
            move "INVALID_REQUEST" to px-result-error
            exit perform
        end-if
        if px-tb-result-error(call-number) not = spaces
            move px-tb-result-error(call-number) to px-result-error
            exit perform
        end-if
        if px-tb-result-output-length(call-number) < 0
            or > 2048
            move "INVALID_REQUEST" to px-result-error
            exit perform
        end-if
        add 1 to px-message-count of work-session
        move px-message-count of work-session to message-number
        initialize px-messages of work-session(message-number)
        move "tool" to px-role of work-session(message-number)
        move px-tb-result-output(call-number)
            to px-content of work-session(message-number)
        move px-tb-result-output-length(call-number)
            to px-content-length of work-session(message-number)
        move px-tb-call-id(call-number)
            to px-message-call-id of work-session(message-number)
    end-perform.

emit-stream.
    if px-stream-program = spaces exit paragraph end-if
    move spaces to stream-status
    call px-stream-program using px-stream-part px-user-data stream-status
        on exception move "STREAM_ERROR" to stream-status
    end-call
    if stream-status not = spaces
        move stream-status to px-result-error
    end-if.

emit-event.
    if px-event-program = spaces exit paragraph end-if
    move spaces to event-status
    call px-event-program using px-event px-user-data event-status
        on exception continue
    end-call.
end program praxo-run.
