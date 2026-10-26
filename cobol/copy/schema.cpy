       01 px-schema-request.
          05 px-sch-schema pic x(32768).
          05 px-sch-schema-length binary-long.
          05 px-sch-data pic x(32768).
          05 px-sch-data-length binary-long.
       01 px-schema-result.
          05 px-sch-error-count binary-long.
          05 px-sch-errors occurs 64 times.
             10 px-sch-path pic x(256).
             10 px-sch-message pic x(128).
          05 px-sch-error pic x(64).
