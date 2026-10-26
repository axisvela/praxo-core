       01 px-context-request.
          05 px-ctx-op pic x(16).
          05 px-ctx-max-tokens pic s9(15) comp-3.
          05 px-ctx-keep-recent binary-long.
          05 px-ctx-count binary-long.
          05 px-ctx-messages occurs 64 times.
             10 px-ctx-role pic x(16).
             10 px-ctx-content pic x(2048).
             10 px-ctx-content-length binary-long.
       01 px-context-result.
          05 px-ctx-ok pic 9.
          05 px-ctx-tokens pic s9(15) comp-3.
          05 px-ctx-out-count binary-long.
          05 px-ctx-out occurs 64 times.
             10 px-ctx-out-role pic x(16).
             10 px-ctx-out-content pic x(2048).
             10 px-ctx-out-content-length binary-long.
          05 px-ctx-error pic x(64).
