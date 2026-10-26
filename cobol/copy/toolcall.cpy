        01 px-toolcall-request.
          05 px-tc-op pic x(16).
          05 px-tc-content pic x(32768).
          05 px-tc-length binary-long.
       01 px-toolcall-result.
          05 px-tc-found pic 9.
          05 px-tc-name pic x(128).
          05 px-tc-name-length binary-long.
          05 px-tc-input pic x(16384).
          05 px-tc-input-length binary-long.
          05 px-tc-text pic x(32768).
          05 px-tc-text-length binary-long.
          05 px-tc-error pic x(64).
