# PRAXO-Integration Skill Template

This directory contains a tool-neutral `SKILL.md` for coding tools that support
agent skills. It is a repository template, not an automatically installed or
automatically discovered skill.

- Codex, Claude Code, Copilot, and other tools use different installation,
  discovery, and mounting mechanisms. Follow the tool's own documentation.
- Copying this directory into a repository does not guarantee that a tool will
  load it.
- The skill contains no hidden install step and does not create MCP servers,
  runtime skills, or external services.
- The canonical integration contract remains
  [`docs/getting-started/coding-agents.md`](../../docs/getting-started/coding-agents.md)
  and the machine-readable map is
  [`agent-integration.json`](../../docs/getting-started/agent-integration.json).

## Verified Tool Examples

Claude Code `2.1.196` was locally verified on 2026-11-08 to list this template as
a skill component after installation through its skills-directory plugin flow.
This is structural discovery evidence only: it does not show that a task loads
the skill, installs a published package, or passes allow/deny checks.

opencode `1.18.18` was locally verified on 2026-11-08 to discover this template
from a project-local `.opencode/skills/praxo-integration/SKILL.md` and to complete
a deterministic task with published PyPI `praxo-core==0.3.2`, explicit tool scope,
and allow/deny tests (3/3 passed). This is one tool, one task, and one platform;
it does not cover the governed negative matrix or live models. Codex, Copilot,
and other tools remain unverified.

If a tool cannot install a skill, use the coding-agent page and consumer
starters directly. The skill is an optional convenience layer.

See [Agent Skills](../../docs/getting-started/coding-agents.md#agent-skills) for
the boundary between coding-agent skills and runtime skills.
