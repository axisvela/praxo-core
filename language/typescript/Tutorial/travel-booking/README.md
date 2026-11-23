# TypeScript travel booking

A native TypeScript Core tutorial for review-only flight booking. It checks fixed
`trip-100` inventory and drafts a fare hold with no payment or booking write. The
model packages computed evidence into a JSON report. This tutorial does not pay,
ticket, change inventory, read arbitrary data or call a live model.

## Run

From this directory:

```bash
npm install --ignore-scripts --no-audit --no-fund
npm test
node app.js
node app.js --trip trip-200
node app.js --simulate-failure
```

Expected test output:

```text
TypeScript travel-booking tutorial: all checks passed
```

`trip-200` is denied by policy before the inventory tool runs and exits non-zero.
`--simulate-failure` fails after one read.

## Path

1. `check_inventory` returns `fare-100`, route `AMS-SIN`, four seats left, price
   `640` and `refundable=true` for `trip-100`.
2. `draft_booking` returns `status=draft_only`, `review_required=true`,
   `payment_executed=false` and `bookings_writes=0` for `hold_fare`.
3. The deterministic model packages both tool results into a JSON report.

The application owns fare rules, payment, ticketing, inventory writes and effect
reconciliation.

## Scope

This is source and local fixture evidence. It does not establish a real inventory
system, payment, ticketing, live provider, public hosting or independent adoption.
The tools and report fields are tutorial-local and are not Core or wire API.
