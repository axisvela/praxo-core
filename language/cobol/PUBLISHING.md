# Releasing the COBOL Core

## Status

COBOL has no central package-registry publication. The release is a source tag,
`cobol/v0.6.0`, plus the GitHub release/source archive.

## Build and test

Prerequisite: GnuCOBOL 2.0 or later and Python 3.10+.

```bash
python language/cobol/run-tests.py
python language/cobol/api-snapshot.py --check
```

The driver builds the combined native suites and runs the vector, agent,
behavior, SSE, JSON, contract, tooling, and API snapshot checks.

## Release

1. Update `language/cobol/CHANGELOG.md`, `README.md`, and the API snapshot
   target.
2. Run the gates above.
3. Create the source tag:

```bash
git tag -a cobol/v0.6.0 -m "praxo-core COBOL v0.6.0"
git push origin cobol/v0.6.0
```

## Credentials and configuration

- No registry token or package-registry account is used.
- GnuCOBOL and its runtime are external toolchain dependencies.
- GitHub release publication uses the repository release workflow.

## Verify

```bash
python language/cobol/run-tests.py
python language/cobol/api-snapshot.py --check
```
