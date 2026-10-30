       01 px-registry-state.
          05 entry-count binary-long value 0.
          05 stored-entries occurs 32 times.
             10 stored-name pic x(64).
             10 stored-name-length binary-long.
             10 stored-description pic x(256).
             10 stored-description-length binary-long.
             10 stored-program pic x(64).
             10 stored-program-length binary-long.
             10 stored-risk pic x(16).
             10 stored-risk-length binary-long.
