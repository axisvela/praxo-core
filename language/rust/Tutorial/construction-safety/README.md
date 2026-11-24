# Rust construction safety (BE-01)

A bounded first slice of BE-01, not a certified safety inspection. It reads fixed
inspection labels for one site, drafts a review-only remediation checklist and
records zero certified findings. No vision, field access or safety certification.

## Why this language and runtime?

- **Selection basis:** A Rust site or inspection tool can embed the review boundary
  beside its field data handling. No construction consumer is verified.
- **Demonstrated fit:** Fixed inspection labels produce a review-only checklist; no
  image model, permit system or field device is accessed.
- **Choose when:** Learning the Core seam for an existing Rust inspection tool.
- **Do not choose when:** Seeking certified safety findings or remediation control.
  Compare the site's inspection process and deterministic checklists first.
- **Evidence limit:** Core integration fixture only; no vision, field access,
  certified finding, permit authority or remediation action.

Run from this directory:

```bash
cargo run --quiet --locked -- --test
cargo run --quiet --locked --
cargo run --quiet --locked -- --site site-200
cargo run --quiet --locked -- --simulate-failure
```

Expected test output:

```text
success: site-100 inspection=scaffold findings=2 status=draft_only certified=0 reads=1
deny: AGENT_POLICY_DENIED reads=0
failure: SITE_SOURCE_UNAVAILABLE reads=1
```

`site-200` is denied by policy before the adapter is called and exits `2`.
`--simulate-failure` reads once, reports `SITE_SOURCE_UNAVAILABLE`, and exits `1`.

`read_site` returns a scaffold inspection with two labeled findings
(`missing-guardrail`, `expired-harness-tag`) for `site-100`; `draft_checklist`
returns `status=draft_only`, `review_required=true`, two remediation items,
`certified_findings=0` and `writes=0`. Policy limits the site and final
`draft_remediation` action.

Real image/label analysis, certified inspection, permit authority and field
remediation belong to the consumer.
