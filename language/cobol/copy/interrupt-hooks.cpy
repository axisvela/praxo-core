       interrupt-hooks.
           move 0 to skip-tool-flag
           if px-interrupt-count <= 0 exit paragraph end-if
           move 0 to tool-allowed-flag
           perform varying allowed-index from 1 by 1
               until allowed-index > px-interrupt-count
               if px-interrupt-tools(allowed-index) = px-tool-name
                   move 1 to tool-allowed-flag
               end-if
           end-perform
           if tool-allowed-flag = 0 exit paragraph end-if
           if px-interrupt-program = spaces
               move "AGENT_INTERRUPT_UNHANDLED" to px-result-error
               exit paragraph
           end-if
           initialize px-event
           move "tool.interrupt" to px-event-kind
           move px-tool-name to px-event-tool
           perform emit-event
           initialize px-interrupt
           move spaces to px-status
           call px-interrupt-program using px-call px-interrupt
               px-user-data px-status
               on exception
                   move "AGENT_INTERRUPT_DECISION_INVALID" to px-status
           end-call
           if px-status not = spaces
               move px-status to px-result-error
               exit paragraph
           end-if
           evaluate px-interrupt-action
               when "approve"
                   continue
               when "edit"
                   if px-interrupt-input-length < 0
                       or > 2048
                       move "AGENT_INTERRUPT_DECISION_INVALID"
                           to px-result-error
                       exit paragraph
                   end-if
                   move px-interrupt-input to px-tool-input
                   move px-interrupt-input-length
                       to px-tool-input-length
               when "reject"
                   move "AGENT_APPROVAL_DENIED" to px-result-error
                   exit paragraph
               when "respond"
                   move 1 to skip-tool-flag
               when other
                   move "AGENT_INTERRUPT_DECISION_INVALID"
                       to px-result-error
                   exit paragraph
           end-evaluate.

       reauthorize-tool.
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

       append-skip-result.
           add 1 to px-message-count of work-session
           move px-message-count of work-session to message-number
           initialize px-messages of work-session(message-number)
           move "tool" to px-role of work-session(message-number)
           move px-interrupt-response
               to px-content of work-session(message-number)
           move px-interrupt-response-length
               to px-content-length of work-session(message-number)
           move px-tool-id
               to px-message-call-id of work-session(message-number).
