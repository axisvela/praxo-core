# OCaml architecture graph (OG-01)

A bounded first slice of OG-01, not an enterprise-architecture control plane. It
compares a fixed application/API graph with stated standards and drafts
review-only change findings. No production scanning, automatic blocking or live
model.

## Why this language and runtime?

- **Selection basis:** OCaml fits architecture and static-analysis tools that already
  use typed graphs and native executables.
- **Demonstrated fit:** A fixed application/API graph yields review-only findings; no
  CMDB discovery, standards engine or blocking action runs.
- **Choose when:** Learning the Core seam in an existing OCaml analysis tool.
- **Do not choose when:** Seeking production scanning or automated enforcement. Compare
  the existing CMDB, policy engine and change process first.
- **Evidence limit:** Core integration fixture only; no discovery, real graph data,
  standards enforcement, automatic blocking or remediation.

Run from **this directory** (the `#use` path is relative to the working directory):

```bash
ocaml unix.cma review.ml --test
ocaml unix.cma review.ml
ocaml unix.cma review.ml --graph graph-200
ocaml unix.cma review.ml --simulate-failure
```

Expected test output:

```text
success: graph-100 violations=2 high=unapproved_api status=draft_only blocks=0 reads=1
deny: AGENT_POLICY_DENIED reads=0
failure: GRAPH_UNAVAILABLE reads=1
```

`graph-200` is denied by policy before the tool is called and exits `1`.
`--simulate-failure` reads once, reports `GRAPH_UNAVAILABLE`, and exits `1`.

`read_graph` returns 4 nodes, 5 edges and two violations (`unapproved_api` high,
`orphan_service` medium) for `graph-100`; `draft_findings` returns two findings
with `status=draft_only`, `review_required=true` and `blocks=0`. Policy limits the
graph and final `draft_change_findings` action.

Real CMDB discovery, standards enforcement, change blocking and remediation
belong to the consumer.
