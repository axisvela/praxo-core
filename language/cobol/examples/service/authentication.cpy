        01 px-auth-principal.
           05 px-auth-subject pic x(256).
           05 px-auth-subject-length binary-long.
           05 px-auth-tenant pic x(256).
           05 px-auth-tenant-length binary-long.
           05 px-auth-expires binary-long.
           05 px-auth-valid binary-long.
        01 px-auth-introspection-request.
           05 px-auth-endpoint pic x(512).
           05 px-auth-client-id pic x(256).
           05 px-auth-client-secret pic x(256).
           05 px-auth-tenant-claim pic x(64).
           05 px-auth-authorization pic x(2048).
           05 px-auth-now binary-long.
        01 px-auth-revocation-request.
           05 px-auth-token pic x(2048).
           05 px-auth-token-length binary-long.
        01 px-auth-transport-result.
           05 px-auth-status binary-long.
           05 px-auth-body pic x(32768).
           05 px-auth-body-length binary-long.
           05 px-auth-error pic x(64).
