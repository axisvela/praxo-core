# Lua live show (MD-07)

A bounded first slice of MD-07, not a live-stream controller. It replays fixed
synthetic engagement events and drafts a review-only presentation order. No
audience profiling, coupon sends or stream control.

## Why this language and runtime?

- **Selection basis:** Live-production tools and game-like hosts often use Lua for
  runtime scripting, where a presentation-order draft can sit beside existing controls.
- **Demonstrated fit:** Fixed engagement events produce a review-only order; no stream
  control, coupon or audience-profile system runs.
- **Choose when:** Learning a host-scripting review pattern for live direction.
- **Do not choose when:** Seeking stream control or audience analytics. Compare the
  broadcast stack, platform APIs and moderation rules first.
- **Evidence limit:** Core integration fixture only; no live stream, audience profile,
  coupon send, latency guarantee or platform integration.

From this directory:

```bash
lua app.lua --test
lua app.lua
lua app.lua show-200
lua app.lua show-100 --simulate-failure
```

Expected test output: `Lua live-show tutorial: all checks passed`.
The deny and failure commands exit nonzero.

`read_engagement` returns `show-100` with 1200 viewers, peak segment `opening`,
80 likes and 12 shares; `draft_order` returns two ordered segments with
`status=draft_only`, `review=review_required`, `stream_controls=0` and
`coupons=0`. Policy limits the show and final `draft_order` action.

Tests assert one read and one draft on success, zero reads/drafts for a
cross-show denial, and one read/zero drafts for the simulated engagement-index
outage. Real audience analytics, stream control and promotion belong to the
consumer.
