# Independent Python Consumer

Use published `praxo-core==0.3.0` in your own application with Python 3.11 or
newer. No PRAXO-CORE source checkout, API key, model service, or AxisVela product
is required. Installation needs PyPI access or a cached wheel.

## Choose the Boundary

This is a fit for an embedded async model/tool loop with explicit tool scope and
policy. Your application still owns model access, authentic identity, persistent
approvals, external effects, and isolation. It is not a hosted agent platform,
durable graph engine, or sandbox service. See [when not to use Core](when-not-to-use.md).

## Install in a New Application

In a new application directory, create a virtual environment. Use its Python
directly; activation is not necessary.

POSIX:

```sh
python3 -m venv .venv
.venv/bin/python -m pip install --index-url https://pypi.org/simple praxo-core==0.3.0
```

PowerShell:

```powershell
python -m venv .venv
.venv\Scripts\python.exe -m pip install --index-url https://pypi.org/simple praxo-core==0.3.0
```

Do not use `pip install -e`, a repository path, or `PYTHONPATH` to substitute the
SDK. The acceptance tests check the installed package version, its location in
the virtual environment, and the absence of a direct-path installation record.

## Application Source

Use the following as `starter.py`. The documentation site renders the
[tested application source](https://github.com/axisvela/praxo-core/blob/main/examples/consumer-python/starter.py)
directly; GitHub readers can follow the source link.

<!-- python-consumer-source: starter.py -->

## Acceptance Tests

Use the following as `test_starter.py`, rendered from the
[tested source](https://github.com/axisvela/praxo-core/blob/main/examples/consumer-python/test_starter.py).

<!-- python-consumer-source: test_starter.py -->

## Verify

POSIX:

```sh
.venv/bin/python -m pip check
.venv/bin/python -I -m unittest discover -s . -v
.venv/bin/python -I starter.py
```

PowerShell:

```powershell
.venv\Scripts\python.exe -m pip check
.venv\Scripts\python.exe -I -m unittest discover -s . -v
.venv\Scripts\python.exe -I starter.py
```

Expected program output:

```text
allow: recorded; effects=1
deny: policy rejected; effects=0
```

The model is a deterministic fixture, not an LLM. `allowed_tools` limits the tool
name; Policy also checks the target argument. Empty scope does not mean deny-all
in the current API. A denied private target must never reach the in-memory effect
counter. Keep these tests when replacing the fake model with a real adapter.

These checks establish only the stated package and fixture behavior, not live
model quality, production security, or durable execution guarantees. Continue
with the [Python API and implementation guide](../languages/python/index.md) and
the [security model](../security/index.md).
