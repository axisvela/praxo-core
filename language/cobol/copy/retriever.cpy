       01 px-retriever-request.
          05 px-ret-query pic x(2048).
          05 px-ret-query-length binary-long.
          05 px-ret-limit binary-long.
          05 px-ret-callback-program pic x(64).
       01 px-retriever-result.
          05 px-ret-count binary-long.
          05 px-ret-documents occurs 32 times.
             10 px-ret-doc-id pic x(128).
             10 px-ret-doc-id-length binary-long.
             10 px-ret-doc-content pic x(2048).
             10 px-ret-doc-content-length binary-long.
             10 px-ret-doc-metadata pic x(2048).
             10 px-ret-doc-metadata-length binary-long.
             10 px-ret-doc-score-has binary-long.
             10 px-ret-doc-score comp-2.
