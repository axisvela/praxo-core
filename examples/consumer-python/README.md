# Independent Python Consumer

This starter installs `praxo-core==0.3.0` from PyPI in a dedicated virtual
environment. It does not import the repository's Python implementation.
Use Python 3.11 or newer. No runtime dependency other than PRAXO-CORE is needed.

On POSIX, from this directory:

```sh
python3 -m venv .venv
.venv/bin/python -m pip install --index-url https://pypi.org/simple -r requirements.txt
.venv/bin/python -I -m unittest discover -s . -v
.venv/bin/python -I starter.py
```

On PowerShell:

```powershell
python -m venv .venv
.venv\Scripts\python.exe -m pip install --index-url https://pypi.org/simple -r requirements.txt
.venv\Scripts\python.exe -I -m unittest discover -s . -v
.venv\Scripts\python.exe -I starter.py
```

Expected program output:

```text
allow: recorded; effects=1
deny: policy rejected; effects=0
```

The deterministic model requests a tool; an explicit tool scope and policy
restrict the target. A rejected call must not increment the in-memory counter.
The tests verify both behavior and import provenance. Installation needs PyPI
access or a cached wheel; execution needs no credentials or model service.
This does not prove live-model quality, authentic identity, isolation, or
durable effects.

For a new application outside this repository, use the
[consumer guide](../../docs/getting-started/consumer-python.md). From the repository
root, `python scripts/test_python_consumer.py -v` reproduces the flow in a fresh
temporary application and virtual environment.
