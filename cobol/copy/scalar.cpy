       01 px-scalar-request.
          05 px-scalar-schema pic x(32768).
          05 px-scalar-schema-length binary-long.
          05 px-scalar-data pic x(32768).
          05 px-scalar-data-length binary-long.
          05 px-scalar-path pic x(256).
          05 px-scalar-path-length binary-long.
       01 px-scalar-result.
          05 px-scalar-count binary-long.
          05 px-scalar-errors occurs 64 times.
             10 px-scalar-error-path pic x(256).
             10 px-scalar-error-message pic x(128).
          05 px-scalar-error pic x(64).
