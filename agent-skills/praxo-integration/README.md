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

If a tool cannot install a skill, use the coding-agent page and consumer
starters directly. The skill is an optional convenience layer.

See [Agent Skills](../../docs/getting-started/coding-agents.md#agent-skills) for
the boundary between coding-agent skills and runtime skills.
