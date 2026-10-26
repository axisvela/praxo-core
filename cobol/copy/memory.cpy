       01 px-memory-request.
          05 px-mem-op pic x(16).
          05 px-mem-session pic x(128).
          05 px-mem-session-length binary-long.
          05 px-mem-query pic x(2048).
          05 px-mem-query-length binary-long.
          05 px-mem-limit binary-long.
          05 px-mem-id pic x(64).
          05 px-mem-id-length binary-long.
          05 px-mem-frame pic x(32).
          05 px-mem-content pic x(2048).
          05 px-mem-content-length binary-long.
          05 px-mem-created pic x(40).
       01 px-memory-result.
          05 px-mem-count binary-long.
          05 px-mem-records occurs 64 times.
             10 px-mem-res-id pic x(64).
             10 px-mem-res-id-length binary-long.
             10 px-mem-res-content pic x(2048).
             10 px-mem-res-content-length binary-long.
             10 px-mem-res-created pic x(40).
          05 px-mem-error pic x(64).
