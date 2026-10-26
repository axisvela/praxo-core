       01 px-json-input.
          05 px-json-text pic x(32768).
          05 px-json-length binary-long.
       01 px-json-document.
          05 px-json-count binary-long.
          05 px-json-nodes occurs 512 times.
             10 px-json-kind pic x.
             10 px-json-parent binary-long.
             10 px-json-start binary-long.
             10 px-json-size binary-long.
             10 px-json-value pic x(2048).
             10 px-json-value-length binary-long.
       01 px-json-string.
          05 px-string-value pic x(2048).
          05 px-string-length binary-long.
       01 px-json-output.
          05 px-output-text pic x(16384).
          05 px-output-length binary-long.
       01 px-json-cursor binary-long.
       01 px-json-error pic x(64).
