# C++ Live Model

This example connects the C++ Core to an OpenAI-compatible endpoint through the
existing `OpenAICompatible` adapter and registers one low-risk `get_time(zone)`
tool. The model may only call `get_time`; every other tool call is denied by
policy.

## Run

Build from the C++ CMake build directory, then run
`praxo-cpp-live-model-example`. Or compile directly:

```bash
g++ -std=c++20 -I language/cpp/include language/cpp/examples/live-model/main.cpp \
  language/cpp/build/libpraxo_cpp.a -o build/cpp-live-model
./build/cpp-live-model
```

Environment variables:

```bash
export PRAXO_BASE_URL=http://localhost:11434/v1
export PRAXO_MODEL=qwen3.5:4b
# export PRAXO_API_KEY=...   # only for hosted endpoints
export PRAXO_PROMPT="What time is it? Use get_time with zone set to utc and reply with the time."
```

PowerShell:

```powershell
$env:PRAXO_BASE_URL = "http://localhost:11434/v1"
$env:PRAXO_MODEL = "qwen3.5:4b"
$env:PRAXO_PROMPT = "What time is it? Use get_time with zone set to utc and reply with the time."
```

## Transport seam

The C++ Core bundles no HTTP client. `OpenAICompatible` takes a caller-owned
transport:

```cpp
using OpenAICompatibleTransport = std::function<Json(
    const std::string& url, const Json& payload,
    const std::map<std::string, std::string>& headers)>;
```

Return the decoded JSON response. The example ships a transport that throws
`PROVIDER_HTTP`; replace the `transport` lambda in `main.cpp` with a transport
built on your HTTP library. Without it the example prints troubleshooting for
`PRAXO_BASE_URL`, `PRAXO_MODEL`, and `PRAXO_API_KEY` and exits nonzero.

A small `SchematizedModel` wrapper advertises the `get_time` JSON Schema because
the default registry specs only carry name and description. The example
authorizes only `get_time`; every other tool call is denied by policy. It is an
integration starting point, not a production security profile. Identity,
durable approvals, isolation, and effect reconciliation remain the
application's responsibility.
