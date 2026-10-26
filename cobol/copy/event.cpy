       01 px-event-request.
          05 px-evt-op pic x(8).
          05 px-evt-predicate-count binary-long.
          05 px-evt-predicates occurs 32 times pic x(32).
          05 px-evt-count binary-long.
          05 px-evt-events occurs 64 times pic x(32).
          05 px-evt-sink-count binary-long.
       01 px-event-result.
          05 px-evt-delivered-count binary-long.
          05 px-evt-delivered occurs 64 times pic x(32).
          05 px-evt-sink-total binary-long.
          05 px-evt-sinks occurs 8 times.
             10 px-evt-sink-type-count binary-long.
             10 px-evt-sink-types occurs 64 times pic x(32).
          05 px-evt-error pic x(64).
