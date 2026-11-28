# Verification Evidence

**Status:** public evidence summary, updated 2026-11-27. Current core release:
`2.11.3`. Earlier records retain
their original revisions and limits.

This page indexes the verification claims PRAXO-CORE can support today. It is a
public summary, not a production certificate, penetration test, or claim that
every implementation and deployment inherits the same result. Raw run records
and full environment logs remain in restricted internal storage; this page
records the claim level, result, and remaining limits.

For the EC-01 through EC-14 mapping across Core and its product consumers, see
the [Execution Correctness Evidence Index](execution-correctness-evidence.md).

See the [test evidence standard](../../contributing/test-evidence.md) for the
required environment, configuration, procedure, data, result, and findings
record.

## Related Pages

- [Contract Status](../status/contract-status.md) summarizes status words and current implementation state.
- [Execution Correctness Evidence](execution-correctness-evidence.md) maps correctness requirements to evidence.
- [Roadmap](../planning/roadmap.md) explains public direction and priorities.

## Claim Levels

| Level | Meaning |
| --- | --- |
| Contract/unit | Deterministic repository tests, fakes, vectors, or API snapshots |
| Local integration | Real local binaries and databases on loopback, with disposable state |
| Independent/production | Reproduced by an independent party or observed in a deployed environment |

Current public evidence does not establish the third level unless a row says so.
A source tag, `complete` matrix label, or passing vector suite is not production
evidence.

## Current Evidence

Detailed evidence is grouped into [core and execution](verification-core-and-execution.md) and [applications](verification-applications.md).

### Tutorial CI Follow-up (2026-11-25) {#tutorial-ci-follow-up-2026-11-25}

Moved to [Tutorial CI Follow-up (2026-11-25)](verification-core-and-execution.md#tutorial-ci-follow-up-2026-11-25).

### Core, Execution, and Live Model {#core-execution-and-live-model}

Moved to [Core, Execution, and Live Model](verification-core-and-execution.md#core-execution-and-live-model).

### Packages, Identity Examples, and Consumer Runs {#packages-identity-examples-and-consumer-runs}

Moved to [Packages, Identity Examples, and Consumer Runs](verification-core-and-execution.md#packages-identity-examples-and-consumer-runs).

### Reference Applications {#reference-applications}

Moved to [Reference Applications](verification-applications.md#reference-applications).

### Cross-Language Behavior and Integration Safety {#cross-language-behavior-and-integration-safety}

Moved to [Cross-Language Behavior and Integration Safety](verification-core-and-execution.md#cross-language-behavior-and-integration-safety).

### Coding-Agent and Adoption {#coding-agent-and-adoption}

Moved to [Coding-Agent and Adoption](verification-applications.md#coding-agent-and-adoption).

### Product and Embedded Evidence {#product-and-embedded-evidence}

Moved to [Product and Embedded Evidence](verification-applications.md#product-and-embedded-evidence).

## Public Evidence Links

- [Compatibility lab](../../languages/compatibility-lab.md) and the [recorded CI compatibility job](https://github.com/axisvela/praxo-core/actions/runs/41000572198/job/123883752839)
- [Behavior lab](../../languages/behavior-lab.md) and the [CI behavior job at `b6218e5`](https://github.com/axisvela/praxo-core/actions/runs/41407891314/job/125153985339)

CI links above point to recorded runs. They are evidence for the revision named
by the run, not proof that the current `main` passes.
Registry links name the current published version; the consumer-smoke rows above
name the version that was actually installed.

- [Current registry versions and addresses](../../languages/registry-status.md)
- [praxo-core 0.11.2 on PyPI](https://pypi.org/project/praxo-core/0.11.2/)
- [@axisvela/praxo-core 0.10.1 on npm](https://www.npmjs.com/package/@axisvela/praxo-core/v/0.10.1)
- [praxo-core 0.11.1 on crates.io](https://crates.io/crates/praxo-core/0.11.1)
- [praxo_core 0.8.2 on pub.dev](https://pub.dev/packages/praxo_core/versions/0.8.2)
- [praxo-core 0.10.2 on RubyGems](https://rubygems.org/gems/praxo-core/versions/0.10.2)
- [praxo-core 0.9.1-1 on LuaRocks](https://luarocks.org/modules/hanhhuiwen/praxo-core/0.9.1-1)
- [praxo_core 0.11.1 on Hex](https://hex.pm/packages/praxo_core/0.11.1)
- [Praxo.Core 0.11.1 on NuGet](https://www.nuget.org/packages/Praxo.Core/0.11.1)
- [axisvela/praxo-core 0.10.2 on Packagist](https://packagist.org/packages/axisvela/praxo-core/0.10.2)
- [praxo_core_erlang 0.10.1 on Hex](https://hex.pm/packages/praxo_core_erlang/0.10.1)
- [praxo-core-ps 0.9.1 on PowerShell Gallery](https://www.powershellgallery.com/packages/praxo-core-ps/0.9.1)
- [Praxo-Core 0.8.1 on MetaCPAN](https://metacpan.org/release/HANHHUIWEN/Praxo-Core-0.8.1)
- [praxo-core 0.8.0 on DUB](https://code.dlang.org/packages/praxo-core/versions/0.8.0)
- [com.axisvela:praxo-core 0.12.3 on Maven Central](https://repo1.maven.org/maven2/com/axisvela/praxo-core/0.12.3/)
- [Governed workspace example](https://github.com/axisvela/praxo-core/tree/main/language/go/examples/governed-workspace)
- [Governed execution design](../../reference/governed-execution.md)
- [OpenTelemetry runnable example](https://github.com/axisvela/praxo-core/tree/main/adapters/otel/example)
- [A2A interoperability example](https://github.com/axisvela/enterprise-autonomy/tree/main/examples/a2a-adk-order-cancellation)
- [Agent IAM examples](https://github.com/axisvela/enterprise-autonomy/tree/main/examples/a2a-agent-iam)
- [Integration recovery demo](https://github.com/axisvela/enterprise-autonomy/tree/main/examples/integration-recovery-local)
- [Workspace adapter directory](https://github.com/axisvela/praxo-core/tree/main/adapters/workspace)
- [Containment assessment](../../security/containment.md)
- [RHEOVELA](https://github.com/axisvela/rheovela), [PRAXOVELA](https://github.com/axisvela/praxovela), and [AKROVELA](https://github.com/axisvela/akrovela) repositories

## Not Claimed

- Production readiness, deployed SLOs, or capacity under load.
- Independent security review, penetration testing, or compliance certification.
- Generic exactly-once execution or a cross-service transaction.
- Live verification of external workspace providers.
- Live Postgres verification: a local attempt on 2026-11-09 with PostgreSQL 18.1
  on Windows did not complete (server exited with `0xC0000142`); the gated
  Postgres tests require `PRAXO_POSTGRES_DSN` and a healthy server.
- Windows symlink containment when the test host cannot create symlinks.
- Test results for a different commit, tag, binary, or dependency resolution.
- Package-registry availability inferred from a source tag.
- An all-green CI status. Cancelled, failed, or not-run jobs are not passes;
  use the recorded CI links and their stated limits.

## Reporting A Gap

If a claim cannot be reproduced, open an issue with the commit, platform,
commands, inputs, expected result, observed result, and whether the mismatch is a
test defect or a behavior defect. Do not replace a failed record with a later
successful retry; keep both.
