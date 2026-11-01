       01 px-sse-request.
          05 px-sse-text pic x(32768).
          05 px-sse-length binary-long.
       01 px-sse-result.
          05 px-sse-done pic 9.
          05 px-sse-event-count binary-long.
          05 px-sse-content pic x(32768).
          05 px-sse-content-length binary-long.
          05 px-sse-error pic x(64).
