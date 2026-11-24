# Lua live show (MD-07)

A bounded first slice of MD-07, not a live-stream controller. It replays fixed
synthetic engagement events and drafts a review-only presentation order. No
audience profiling, coupon sends or stream control.

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
