       01 px-middleware-request.
          05 px-mw-op pic x(24).
          05 px-mw-text pic x(32768).
          05 px-mw-text-length binary-long.
          05 px-mw-schema pic x(32768).
          05 px-mw-schema-length binary-long.
          05 px-mw-output pic x(32768).
          05 px-mw-output-length binary-long.
          05 px-mw-max-repairs binary-long.
          05 px-mw-repair pic x(32768).
          05 px-mw-repair-length binary-long.
          05 px-mw-run pic x(128).
          05 px-mw-model-limit binary-long.
          05 px-mw-tool-limit binary-long.
          05 px-mw-kind pic x(16).
          05 px-mw-selected-count binary-long.
          05 px-mw-selected occurs 32 times pic x(64).
          05 px-mw-tool-count binary-long.
          05 px-mw-tools occurs 32 times pic x(64).
          05 px-mw-requested pic x(64).
          05 px-mw-requested-length binary-long.
          05 px-mw-fallback pic x(2048).
          05 px-mw-fallback-length binary-long.
       01 px-middleware-result.
          05 px-mw-ok pic 9.
          05 px-mw-result pic x(32768).
          05 px-mw-result-length binary-long.
          05 px-mw-advertised-count binary-long.
          05 px-mw-advertised occurs 32 times pic x(64).
          05 px-mw-error pic x(64).
