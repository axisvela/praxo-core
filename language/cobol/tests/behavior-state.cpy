       01 behavior-state redefines px-user-data.
          05 bh-mode binary-long.
          05 bh-model-count binary-long.
          05 bh-tool-count binary-long.
          05 bh-other-count binary-long.
          05 bh-before-run-count binary-long.
          05 bh-after-run-count binary-long.
          05 bh-before-tool-count binary-long.
          05 bh-tool-policy-count binary-long.
          05 bh-event-count binary-long.
          05 bh-order-count binary-long.
          05 bh-last-input-length binary-long.
          05 bh-last-name pic x(64).
          05 bh-last-input pic x(256).
          05 bh-order occurs 16 times pic x(32).
          05 bh-event-types occurs 16 times pic x(32).
          05 bh-policy-names occurs 4 times pic x(64).
          05 bh-policy-args occurs 4 times pic x(64).
