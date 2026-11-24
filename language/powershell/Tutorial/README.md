# PowerShell Tutorials

Application tutorials live in `Tutorial/`, alongside focused `examples/`.

- [Windows diagnostics](windows-diagnostics/README.md): read-only service and
  disk checks, native PowerShell commands, scoped tools, and a structured report.

PowerShell uses the shared C# Core through its module, not a separately
implemented agent loop. Fixture mode is portable; local machine checks require
Windows and do not execute repairs or arbitrary model-generated commands.

## Article angle

Windows operations with read-only review: object pipelines, cmdlets and the discipline of not changing live services.

## Business scenarios

These PowerShell examples show bounded Agent-shaped workflows rather than complete products. Each one keeps business data, approval and effects in the application:

- [Windows Diagnostics Agent](./windows-diagnostics/README.md)

## Technical capabilities exercised

- Native Core execution in the language runtime, without a sidecar Agent service.
- Application-owned tools with scoped policy checks before tool invocation.
- A denial path and a dependency-failure path with no later draft or write.
- Deterministic fixtures for repeatable local checks; no credential dependency.
- Application-owned identity, persistence, approval and effect reconciliation.

Capabilities not demonstrated by a specific tutorial, such as streaming, HITL or durable checkpoints, must not be inferred from this list.

## Language and runtime fit

PowerShell's object pipeline and cmdlets make it the standard automation shell for Windows administration and Microsoft infrastructure.

Language and ecosystem traits:

- Structured object pipelines instead of text-only shell output.
- Deep Windows/service/AD management integration.
- Readable automation for operators and runbooks.

Trade-offs:

- Windows-centric assumptions and performance limits on huge data.
- Cross-platform support is real but less deep than on Windows.

Praxo-specific fit: The Core seam fits existing Windows runbooks; the fixture does not change services, elevate privileges or administer remote hosts.

## Evidence and limits

These examples record source and local-fixture evidence. Tutorial CI jobs may be added without a verified remote run, and none of these pages claim independent adoption, production deployment or a validated live model unless a tutorial states its own evidence explicitly. See the [Tutorial Plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) and [Verification Evidence](https://axisvela.github.io/praxo-core/project/verification-evidence/) for scope conventions.

## Where to start

Open the [Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) and filter by PowerShell, or select the first business scenario above. Follow the tutorial's own README for exact commands and expected output.
