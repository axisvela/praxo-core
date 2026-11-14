# Elixir Examples

- [`consumer/`](consumer/): published Hex `praxo_core==0.8.0` starter with
  deterministic allow/deny checks.
- [`hitl/`](hitl/): approval and edit-reauthorization for a write tool.
- [`session-checkpoint/`](session-checkpoint/): multi-turn history save, reload,
  and continue.

The consumer installs a published package. The HITL and checkpoint examples run
from the compiled repository source with `-pa language/elixir/build/ebin`.
