       01 px-options.
          05 px-model-program pic x(64).
          05 px-tool-program pic x(64).
          05 px-policy-program pic x(64).
          05 px-event-program pic x(64).
          05 px-max-steps binary-long.
          05 px-max-tokens pic s9(15) comp-3.
       01 px-session.
          copy "history.cpy".
       01 px-prompt.
          05 px-prompt-text pic x(2048).
          05 px-prompt-length binary-long.
       01 px-result.
          05 px-result-output pic x(2048).
          05 px-result-length binary-long.
          05 px-result-steps binary-long.
          05 px-result-input-tokens pic s9(15) comp-3.
          05 px-result-output-tokens pic s9(15) comp-3.
          05 px-result-error pic x(64).
       01 px-user-data pic x(4096).
