# Provider Fallback

This example uses published PyPI `praxo-core==0.6.0` to fall back to a second
model when the primary model call fails.

`AgentOptions(fallback_model=...)` installs a model middleware. The fallback is
used only after the primary fails; the primary remains first in the normal path.

## Run the deterministic test

No endpoint is required:

```bash
python -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
.venv/bin/python -m unittest test_fallback.py -v
```

## Wiring real adapters

Replace the fake models in `fallback.py` with two published adapters, for
example an OpenAI-compatible primary and a second provider:

```python
primary = OpenAICompatibleModel(OpenAIConfig.for_provider("openai", "gpt-4o-mini", key))
fallback = OpenAICompatibleModel(OpenAIConfig.for_provider("deepseek", "deepseek-chat", key2))
```

The fallback is a resilience mechanism, not a provider SLA or a guarantee that
both providers agree on behavior.
