# Haskell Live Model

This example connects the Haskell Core to an OpenAI-compatible endpoint through
`Praxo.OpenAICompatible`, registers a `get_time(zone)` tool with a small JSON
Schema, and restricts the run to `get_time`.

## Run

From the repository root:

```bash
runghc -ilanguage/haskell/src language/haskell/examples/live-model/live_starter.hs
```

Environment:

```powershell
$env:PRAXO_BASE_URL = "http://localhost:11434/v1"
$env:PRAXO_MODEL = "qwen3.5:4b"
# $env:PRAXO_API_KEY = "..."   # only for hosted endpoints
# $env:PRAXO_PROMPT = "What time is it? Use get_time with zone set to utc and reply with the time."
```

On POSIX use the equivalent `export` commands.

## Transport requirement

`Praxo.OpenAICompatible` is a transport-seam adapter: the package depends only on
GHC boot packages and does not bundle an HTTP client. To reach a live endpoint,
supply a caller-owned `Transport` that performs the synchronous HTTP exchange,
for example with the `http-client` or `http-conduit` package:

```haskell
import qualified Data.ByteString.Char8 as B8
import qualified Data.ByteString.Lazy.Char8 as L8
import qualified Network.HTTP.Simple as HTTP

httpTransport :: Transport
httpTransport = Transport $ \request -> do
    parsed <- HTTP.parseRequest (httpURL request)
    let headers = [(B8.pack name, B8.pack value) | (name, value) <- httpHeaders request]
        prepared = HTTP.setRequestMethod (B8.pack (httpMethod request))
                 $ HTTP.setRequestHeaders headers
                 $ HTTP.setRequestBodyString (httpBody request) parsed
    response <- HTTP.httpLBS prepared
    pure (Right (HttpResponse
        (HTTP.getResponseStatusCode response)
        (L8.unpack (HTTP.getResponseBody response))))
```

This example keeps the repository build dependency-free, so it ships a stub
transport. Running it without replacing the stub prints a troubleshooting line
about `PRAXO_BASE_URL`, `PRAXO_MODEL`, and `PRAXO_API_KEY` and exits nonzero.
The example is structurally runnable; the live network path is documented-only
until a transport from an HTTP package is supplied.

The clock uses GHC's boot `time` package. The `praxo-core` library itself still
depends only on `base` and `containers`.

The example authorizes only `get_time`; every other tool call is denied by
`allowedTools` and the policy. It is an integration starting point, not a
production security profile. Identity, durable approvals, isolation, and effect
reconciliation remain the application's responsibility.
