       01 px-response.
          05 px-answer pic x(2048).
          05 px-answer-length binary-long.
          05 px-input-tokens pic s9(15) comp-3.
          05 px-output-tokens pic s9(15) comp-3.
          05 px-call-count binary-long.
          05 px-calls occurs 8 times.
             10 px-call-id pic x(64).
             10 px-call-name pic x(64).
             10 px-call-input pic x(2048).
             10 px-call-input-length binary-long.
       01 px-call.
          05 px-tool-id pic x(64).
          05 px-tool-name pic x(64).
          05 px-tool-input pic x(2048).
          05 px-tool-input-length binary-long.
       01 px-tool-result.
          05 px-tool-output pic x(2048).
          05 px-tool-output-length binary-long.
       01 px-action.
          05 px-action-kind pic x(32).
          05 px-action-tool pic x(64).
          05 px-action-input pic x(2048).
          05 px-action-input-length binary-long.
       01 px-event.
          05 px-event-kind pic x(32).
          05 px-event-tool pic x(64).
       01 px-status pic x(64).
