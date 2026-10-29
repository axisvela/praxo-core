# Test Evidence Standard

**Status:** documentation standard, 2026-10-29. This defines the record expected
for new verification claims; it does not claim existing runners enforce it.
Historical records remain historical and must not be backfilled with guessed data.

## Scope and Outcomes

Record environment, configuration, procedure, data, results, and findings for
each verification execution. A suite may share common context, but each scenario
must identify its inputs, assertions, outcome, and artifacts. A run-record ID is
distinct from an agent run ID and from a business idempotency key.

Use `passed`, `failed`, `skipped`, `blocked`, and `not-run` as distinct outcomes.
Label structure-only checks separately from execution tests. A command exit code
alone does not prove the required assertions or scenarios ran. Missing tools,
credentials, services, or required evidence are not passes.

Define the required scenario inventory before execution. A strict acceptance run
is satisfied only when every required scenario passes with its required evidence;
required skips, missing scenarios, and blocked cases make acceptance unsatisfied.
Report optional exclusions explicitly. Retries are separate attempts; retain
initial failures rather than replacing them with the successful retry.

## Required Record

| Section | Required content |
| --- | --- |
| Identity and scope | Unique execution ID; UTC start/end; purpose; test layer; required scenario inventory; operator/automation identity suitable for disclosure |
| Versions | Repository URLs and full SHAs; tags/package versions; clean/dirty state and patch artifact when applicable; actual dependency resolution and local replacements; binary/container digests |
| Environment | OS/architecture; runtime/compiler; CPU/memory where relevant; container/VM and isolation mode; database/provider/model versions; topology and network/proxy/TLS conditions |
| Configuration | Exact commands and working directories; sanitized effective configuration; feature flags; timeout, concurrency, retry, budget and resource limits; credential source and non-secret permission scope |
| Procedure | Prerequisites, build/install, seed/setup, health checks, execution steps, fault injection, verification queries, cleanup and observed deviations |
| Data | Fixture/generator revision, seed and input digest; sanitized representative inputs; initial state; expected outputs/effects; namespaces, operation IDs and reset/isolation rules |
| Results | Actual outputs/effects; assertion-level expected versus observed values; exit codes; per-scenario outcomes; pass/fail/skip/blocked/not-run counts; artifact references |
| Findings | Reproduced defects, unexpected behavior, limitations, residual risks, issue references, disposition and follow-up verification requirements |
| Evidence | Artifact path/URI, media type, byte size and SHA-256; source execution ID; access/retention policy; redaction description; reviewer and review status when applicable |

For live model/provider tests, also record endpoint class, model identifier,
sampling settings, provider request IDs when safe, and known nondeterminism.
Record observable versions and mark unavailable details unknown; never infer
server builds or production properties from a successful request.

## Evidence Integrity

Use a fresh execution-specific output directory. Aggregate only artifacts from
that execution and selected scenarios; old `.local-data` files are not current
evidence. Preserve original attempt IDs and timestamps. Do not report a previous
success after a current failure, skip, or structure-only check.

Cross-repository runs must resolve the actual source/binary used, not only the
version in `go.mod` or another manifest. Separate pinned release consumption from
local-source integration. Publish a verification matrix linking claims to these
records rather than copying tests into every repository.

Artifact hashes establish integrity relative to a recorded digest, not independent
execution or correctness. Distinguish author-run, independently reproduced, and
production-observed evidence. If artifacts are unavailable, limit the claim to
the available summary and state the reproducibility gap.

## Privacy and Retention

Never publish tokens, private keys, connection-string passwords, tenant data, or
unapproved personal data. Record credential references and permission classes,
not credential values. Use synthetic data and approved public hostnames in public
records. Review logs, commands, environment dumps, and database exports before
publication; do not rely solely on automatic PII middleware.

Keep restricted raw artifacts in approved storage with access control and a
retention deadline. Publish separately sanitized artifacts and their own hashes;
record redaction without disclosing removed values. Do not claim a sanitized
file is byte-identical to the raw evidence. Evidence manifests must not expose
secrets through low-entropy secret-value hashes.

## Run Record Template

```markdown
# Verification Record: <execution-id>

## Scope
Purpose, UTC start/end, author/automation, test layer, required scenario IDs.
Acceptance: satisfied / unsatisfied / not-evaluated.

## Environment
OS, architecture, runtimes, services, topology, isolation, resource limits.

## Versions and Configuration
Full SHAs, dirty state, binary digests, dependency replacements, sanitized
effective settings, credential references, exact commands and working directories.

## Procedure
Setup, initial state, health checks, ordered execution, injected faults,
verification queries, cleanup, deviations, attempt IDs.

## Data
Fixture/generator revision, seed, input digest, synthetic samples, expected
effects, operation IDs, namespace isolation and reset method.

## Results
Scenario | Required | Expected/assertion | Observed | Outcome | Artifact
Counts: passed / failed / skipped / blocked / not-run; structure-only checks.

## Findings
Defects, unknowns, residual risks, issue links, disposition, retest requirements.
Use "none observed within scope" only when the relevant checks actually ran.

## Artifacts and Review
URI/path, execution ID, SHA-256, byte size, redaction, access and retention.
Review status and reviewer; independent reproduction status; limits on claims.
```
