       01 px-agent-vector-request.
          05 px-av-prompt pic x(2048).
          05 px-av-prompt-length binary-long.
          05 px-av-script-count binary-long.
          05 px-av-script occurs 16 times.
             10 px-av-content pic x(2048).
             10 px-av-content-length binary-long.
             10 px-av-output-tokens pic s9(15) comp-3.
             10 px-av-input-tokens pic s9(15) comp-3.
             10 px-av-call-count binary-long.
             10 px-av-calls occurs 8 times.
                15 px-av-call-name pic x(64).
                15 px-av-call-name-length binary-long.
                15 px-av-call-args pic x(2048).
                15 px-av-call-args-length binary-long.
          05 px-av-tool-count binary-long.
          05 px-av-tools occurs 16 times pic x(64).
          05 px-av-max-steps binary-long.
          05 px-av-max-tokens pic s9(15) comp-3.
       01 px-agent-vector-result.
          05 px-av-result-output pic x(2048).
          05 px-av-result-output-length binary-long.
          05 px-av-steps binary-long.
          05 px-av-event-count binary-long.
          05 px-av-events occurs 64 times pic x(32).
          05 px-av-invocations binary-long.
          05 px-av-error pic x(64).
