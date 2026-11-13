# Streaming

This example uses published PyPI `praxo-core==0.6.0` to consume deltas while the
agent loop keeps running normally.

Set `AgentOptions(on_delta=...)` and implement `generate_stream` on the model.
The agent calls `generate_stream` when a callback is configured, forwards each
delta, and uses the returned `Response` as the final model response.

## Run the deterministic test

No endpoint is required:

```bash
python -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
.venv/bin/python -m unittest test_streaming.py -v
```

## Wiring a real adapter

Replace the fake model with a published streaming adapter, for example
`OpenAICompatibleModel`. Keep application logic on the final result and treat
deltas as incremental display or progress signals.
