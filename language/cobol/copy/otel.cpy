       01 px-otel-options.
          05 px-otel-transport-program pic x(64).
          05 px-otel-endpoint pic x(512).
          05 px-otel-endpoint-length binary-long.
          05 px-otel-service-name pic x(128).
          05 px-otel-service-name-length binary-long.
          05 px-otel-allowed-key-count binary-long.
          05 px-otel-allowed-keys occurs 16 times pic x(64).
       01 px-otel-result.
          05 px-otel-output pic x(16384).
          05 px-otel-output-length binary-long.
          05 px-otel-error-body pic x(512).
          05 px-otel-error-body-length binary-long.
