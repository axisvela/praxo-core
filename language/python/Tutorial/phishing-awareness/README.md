# Python phishing awareness (CY-04)

A bounded first slice of [CY-04](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/),
not a mail-security product. It analyzes one fixed synthetic email and drafts a
review-only awareness exercise. No deceptive sends, live inbox or infrastructure
attack.

## Why this language and runtime?

- **Selection basis:** A Python mail or security workflow can add a review step
  without moving evidence into another service. No mail-security consumer is verified.
- **Demonstrated fit:** Core callbacks return fixed indicators and a draft exercise;
  no message is parsed and no mail system is contacted.
- **Choose when:** Learning the tool/policy boundary in an existing Python workflow.
- **Do not choose when:** Seeking phishing detection or URL analysis. Compare
  existing mail-security filters and deterministic rules first.
- **Evidence limit:** Core integration fixture only; no inbox access, URL detonation,
  classification quality, exercise delivery or detection guarantee.

From this directory:

```bash
python app.py --test
python app.py
python app.py --email email-200
python app.py --simulate-failure
```

Expected test output: `Python CY-04 phishing-awareness tutorial: all checks passed`.
Both negative commands exit nonzero.

`analyze_email` returns three indicators (spoofed sender, suspicious link,
urgency) for `email-100`; `draft_awareness` returns `status=draft_only`,
`review_required=true` and `deceptive_sends=0`. Policy limits the email and final
`draft_exercise` action.

Tests assert one read and one draft on success, zero reads/drafts for a
cross-email denial, and one read/zero drafts for the simulated index outage. Real
mail inspection, URL detonation and authorized exercise delivery belong to the
consumer.
