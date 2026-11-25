       01 application-state redefines px-user-data.
          05 as-tenant pic x(32).
          05 as-mode pic x(16).
          05 as-record-id pic x(16).
          05 as-record-class pic x(16).
          05 as-difference pic x(16).
          05 as-phase binary-long.
          05 as-model-count binary-long.
          05 as-reads binary-long.
          05 as-drafts binary-long.
          05 as-executions binary-long.
          05 as-advisory-saved pic 9.
          05 as-diagnosis pic x(512).
          05 as-rationale pic x(512).
          05 as-trace-count binary-long.
          05 as-trace occurs 16 times pic x(96).
