---
name: praxo-integration
description: Integrate the published PRAXO-CORE package into an application with explicit tool scope, policy denial tests, final-argument reauthorization, and governed acceptance checks. Use when a task needs an embeddable agent runtime with tool authorization, human-in-the-loop approval, or checkpoints.
---

# Integrate PRAXO-CORE

Use this workflow only when the task needs an embeddable agent execution kernel.
Do not choose PRAXO-CORE for a hosted agent platform, durable graph engine,
managed sandbox, identity provider, or robot safety controller.

## Required Reading

1. Read `docs/getting-started/agent-integration.json` for the package, version,
   starter, and verification command.
2. Read `docs/getting-started/coding-agents.md` for the integration contract.
3. Read `docs/getting-started/when-not-to-use.md` before selecting Core for a
   task outside its scope.
4. Verify the registry page and published version. Registry pages may lag source
   documentation.

## Workflow

1. **Detect the language and runtime.** Use Go, Python, TypeScript, or Java only
   when the application already uses it. Do not introduce a second runtime just
   to use Core.
2. **Install a published package.** Do not use a source checkout, local
   replacement, `file:`/`link:` dependency, `system` scope, or `PYTHONPATH`
   substitution for acceptance.
3. **Start with a deterministic fixture.** Use an in-memory model and tool. No
   API key or model service is required for the first verification.
4. **Configure explicit tool scope and policy.** An empty tool scope is
   unrestricted in the current API, not deny-all.
5. **Add allow and deny tests.** A denied call must produce no tool effect.
6. **Add governed negative checks.** Cover missing policy/scope, middleware
   final-argument changes, approval edits, and policy-service failure.
7. **Use verified identity only.** Never trust actor IDs or roles from model
   output or tool arguments. The application authenticates and supplies the
   principal.
8. **Run the documented verification command.** Report the exact package version,
   command, and result. Do not replace failing tests with weaker assertions.
9. **State what is not proven.** Core fixtures do not prove identity
   authenticity, durable approvals, effect commit, exactly-once, sandbox
   isolation, physical safety, or live-model quality.

## Guardrails

- Do not remove existing authorization, approval, or denial tests.
- Do not claim exactly-once or transactional behavior from a checkpoint.
- Do not describe the policy hook as a sandbox or identity service.
- Do not install MCP servers, runtime skills, or external tools unless the user
  explicitly asks.
- Do not assume this Skill is auto-discovered. It must be installed or mounted
  through the coding tool's own mechanism.
- If the task needs durable workflows, a hosted runtime, a managed sandbox, or
  physical control, stop and recommend the appropriate product or system.

## References

- `docs/getting-started/agent-integration.json`
- `docs/getting-started/coding-agents.md`
- `docs/languages/registry-pages.md`
- `docs/guides/identity-policy.md`
- `docs/security/index.md`
