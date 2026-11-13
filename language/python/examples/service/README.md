# HTTP Service

This example embeds published PyPI `praxo-core==0.6.0` in a standard-library
HTTP service. The application supplies a principal and tenant, restricts tools,
and returns JSON.

## Run

```bash
python -m venv .venv
.venv/bin/python -m pip install -r requirements.txt

export PRAXO_BASE_URL=http://localhost:11434/v1
export PRAXO_MODEL=llama3.2
.venv/bin/python service.py
```

```bash
curl -s http://127.0.0.1:8080/run \
  -H 'Content-Type: application/json' \
  -H 'X-Praxo-Principal: user-1' \
  -d '{"prompt":"What time is it? Use get_time."}'
```

The `X-Praxo-Principal` header is an application context stand-in, not
authentication. A production service must verify identity and derive the
principal and tenant from trusted context.

## Test

```bash
.venv/bin/python -m unittest test_service.py -v
```

The test uses a fake model and a loopback HTTP server; no endpoint is required.
