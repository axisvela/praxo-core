       01 px-tool-batch-request.
          05 px-tb-count binary-long.
          05 px-tb-max-parallel binary-long.
          05 px-tb-calls occurs 8 times.
             10 px-tb-call-id pic x(64).
             10 px-tb-call-name pic x(64).
             10 px-tb-call-input pic x(2048).
             10 px-tb-call-input-length binary-long.
       01 px-tool-batch-result.
          05 px-tb-result-count binary-long.
          05 px-tb-results occurs 8 times.
             10 px-tb-result-id pic x(64).
             10 px-tb-result-output pic x(2048).
             10 px-tb-result-output-length binary-long.
             10 px-tb-result-error pic x(64).
       01 px-tool-batch-status pic x(64).
