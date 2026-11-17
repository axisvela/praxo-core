       01 ch-options.
          05 ch-model-program pic x(64).
          05 ch-tool-program pic x(64).
          05 ch-policy-program pic x(64).
          05 ch-require-policy pic 9.
          05 ch-event-program pic x(64).
          05 ch-max-steps binary-long.
          05 ch-max-tokens pic s9(15) comp-3.
          05 ch-before-run-program pic x(64).
          05 ch-before-run-program-2 pic x(64).
          05 ch-before-tool-program pic x(64).
          05 ch-after-run-program pic x(64).
          05 ch-after-run-program-2 pic x(64).
          05 ch-cancel-program pic x(64).
          05 ch-stream-program pic x(64).
          05 ch-tool-batch-program pic x(64).
          05 ch-max-parallel-tools binary-long.
          05 ch-allowed-tool-count binary-long.
          05 ch-allowed-tools occurs 8 times pic x(64).
          05 ch-require-tool-scope pic 9.
          05 ch-interrupt-program pic x(64).
          05 ch-interrupt-count binary-long.
          05 ch-interrupt-tools occurs 8 times pic x(64).
       01 ch-session.
          05 ch-message-count binary-long.
          05 ch-messages occurs 64 times.
             10 ch-role pic x(12).
             10 ch-content pic x(2048).
             10 ch-content-length binary-long.
             10 ch-message-call-id pic x(64).
       01 ch-prompt.
          05 ch-prompt-text pic x(2048).
          05 ch-prompt-length binary-long.
       01 ch-result.
          05 ch-result-output pic x(2048).
          05 ch-result-length binary-long.
          05 ch-result-steps binary-long.
          05 ch-result-input-tokens pic s9(15) comp-3.
          05 ch-result-output-tokens pic s9(15) comp-3.
          05 ch-result-error pic x(64).
