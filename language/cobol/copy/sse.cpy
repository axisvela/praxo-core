       01 px-sse-request.
          05 px-sse-text pic x(32768).
          05 px-sse-length binary-long.
          05 px-sse-delta-program pic x(64).
          05 px-sse-user-data pic x(4096).
       01 px-sse-result.
          05 px-sse-done pic 9.
          05 px-sse-event-count binary-long.
          05 px-sse-content pic x(32768).
          05 px-sse-content-length binary-long.
          05 px-sse-finish-reason pic x(64).
          05 px-sse-input-tokens pic s9(15) comp-3.
          05 px-sse-output-tokens pic s9(15) comp-3.
          05 px-sse-tool-count binary-long.
          05 px-sse-calls occurs 8 times.
             10 px-sse-call-id pic x(64).
             10 px-sse-call-name pic x(64).
             10 px-sse-call-arguments pic x(2048).
             10 px-sse-call-arguments-length binary-long.
          05 px-sse-error pic x(64).
