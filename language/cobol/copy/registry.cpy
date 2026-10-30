       01 px-registry-request.
          05 px-reg-op pic x(8).
          05 px-reg-name pic x(64).
          05 px-reg-name-length binary-long.
          05 px-reg-description pic x(256).
          05 px-reg-description-length binary-long.
          05 px-reg-program pic x(64).
          05 px-reg-program-length binary-long.
          05 px-reg-risk pic x(16).
          05 px-reg-risk-length binary-long.
       01 px-registry-result.
          05 px-reg-count binary-long.
          05 px-reg-entries occurs 32 times.
             10 px-reg-entry-name pic x(64).
             10 px-reg-entry-name-length binary-long.
             10 px-reg-entry-description pic x(256).
             10 px-reg-entry-description-length binary-long.
             10 px-reg-entry-program pic x(64).
             10 px-reg-entry-program-length binary-long.
             10 px-reg-entry-risk pic x(16).
             10 px-reg-entry-risk-length binary-long.
          05 px-reg-error pic x(64).
