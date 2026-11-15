# Objective-C Live Model

This example connects the Objective-C Core to an OpenAI-compatible endpoint
through `PXROpenAIModelCreate`, registers a `get_time(zone)` tool with a small
JSON Schema, and restricts the run to `get_time`.

## Run

macOS with Apple Foundation:

```bash
clang -fobjc-arc -fblocks -Ilanguage/objc/src \
  language/objc/examples/live-model/live_starter.m \
  language/objc/src/PraxoJSON.m language/objc/src/PraxoJsonSchema.m \
  language/objc/src/PraxoCore.m language/objc/src/PraxoAgent.m \
  language/objc/src/PraxoOpenAI.m \
  -framework Foundation -o build/objc-live-model
./build/objc-live-model
```

GNUstep (Linux or Windows):

```bash
clang -fobjc-arc -fblocks -fobjc-runtime=gnustep-2.0 -fuse-ld=lld \
  -Ilanguage/objc/src \
  language/objc/examples/live-model/live_starter.m \
  language/objc/src/PraxoJSON.m language/objc/src/PraxoJsonSchema.m \
  language/objc/src/PraxoCore.m language/objc/src/PraxoAgent.m \
  language/objc/src/PraxoOpenAI.m \
  -lgnustep-base -lobjc -lstdc++ -o build/objc-live-model
./build/objc-live-model
```

Environment:

```powershell
$env:PRAXO_BASE_URL = "http://localhost:11434/v1"
$env:PRAXO_MODEL = "qwen3.5:4b"
# $env:PRAXO_API_KEY = "..."   # only for hosted endpoints
# $env:PRAXO_PROMPT = "What time is it? Use get_time with zone set to utc and reply with the time."
```

On POSIX use the equivalent `export` commands.

`PXROpenAIModelCreate` uses the native `NSURLConnection` transport when no
caller-owned `PXROpenAITransport` is supplied, so this example is fully
runnable with Apple Foundation or GNUstep and network access. The model wrapper
augments the agent request with the `get_time` JSON Schema before calling the
adapter.

The agent exposes no argument-aware policy callback, so the example restricts
the tool name with `toolSelection` and allows only `get_time`. Every other tool
call fails before invocation. It is an integration starting point, not a
production security profile. Identity, durable approvals, isolation, and effect
reconciliation remain the application's responsibility.
