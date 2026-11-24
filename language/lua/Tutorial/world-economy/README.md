# Lua world economy (MD-03)

A bounded first slice of MD-03, not an open-world simulation engine. It reads a
fixed synthetic world economy at one tick and drafts a review-only balance with
no applied change. No scale, equilibrium or long-term stability guarantee.

From this directory:

```bash
lua app.lua --test
lua app.lua
lua app.lua world-200
lua app.lua world-100 --simulate-failure
```

Expected test output: `Lua world-economy tutorial: all checks passed`.
The deny and failure commands exit nonzero.

`read_economy` returns `world-100` at tick 12 with population 30, food 120 and
ore 45; `draft_balance` returns two proposed changes with `status=draft_only`,
`review=review_required`, `applied=false` and `scale_claims=0`. Policy limits the
world and final `draft_balance` action.

Tests assert one read and one draft on success, zero reads/drafts for a
cross-world denial, and one read/zero drafts for the simulated world-store
outage. Real population scale, economy rules and persistence belong to the
consumer.
