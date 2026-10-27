       01 px-policy-request.
          05 px-pol-grant-count binary-long.
          05 px-pol-grants occurs 32 times.
             10 px-pol-root pic x(1024).
             10 px-pol-root-length binary-long.
             10 px-pol-access pic x(16).
             10 px-pol-access-length binary-long.
          05 px-pol-target pic x(4096).
          05 px-pol-target-length binary-long.
          05 px-pol-need pic x(16).
          05 px-pol-need-length binary-long.
       01 px-policy-result.
          05 px-pol-allowed pic 9.
          05 px-pol-error pic x(64).
