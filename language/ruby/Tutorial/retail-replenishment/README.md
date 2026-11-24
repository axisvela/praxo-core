# Ruby Retail Replenishment (CS-05)

Fixed stock, daily sales and lead-time data produce a reorder quantity (22) and a
review-only purchase order. No live pricing, supplier order or inventory write.

## Why this language and runtime?

Ruby fits existing commerce admin and back-office tooling; the tutorial keeps a
bounded replenishment review in that runtime and computes actual quantities.

Evidence limit: fixed SKU and constants only; no inventory feed, price change,
supplier API or purchase submission.
