# Lua storyboard previs (MD-01)

A bounded first slice of MD-01, not a virtual-production pipeline. It reads one
fixed script scene, drafts a review-only shot plan and records zero renders and
zero engine calls. No Unreal integration, media generation or licensed assets.

From this directory:

```bash
lua app.lua --test
lua app.lua
lua app.lua scene-200
lua app.lua scene-100 --simulate-failure
```

Expected test output: `Lua storyboard-previs tutorial: all checks passed`.
The deny and failure commands exit nonzero.

`read_script` returns the fixed scene `scene-100` with beats setup/pursuit/reversal
and constraints `max_shots=6`, `duration_s=45`; `draft_shot_plan` returns three
shots with `status=draft_only`, `review=review_required`, `renders=0` and
`engine_calls=0`. Policy limits the scene and final `draft_previs` action.

Tests assert one read and one plan on success, zero reads/plans for a cross-scene
denial, and one read/zero plans for the simulated script-store outage. Real
storyboard rendering, virtual-production engines and licensing belong to the
consumer.
