# Order Review Agent

First local integration slice, not a completed HR or Web tutorial. The native
Python Core chooses a scoped `review_order` tool. The tool reads a synthetic
order through HTTP and creates a deterministic resolution draft. It never
changes the order or issues a refund. Recommendations are application rules;
model text is not proof that the draft exists.

Start the sibling demo repository's service in another terminal:

The demo repository is currently private and requires authorized access. This
slice is not yet a publicly reproducible tutorial or a publicly hosted service.

```bash
python shared-business-services/service/orders.py
```

From this directory:

```bash
python -m pip install -r requirements.txt
python app.py
python app.py --order order-200
```

The first command prints JSON with `draft.status=draft_only`. The second is
denied by Agent policy before HTTP effects. `DEMO_TOKEN=demo-b-token` also
demonstrates independent server-side denial for `order-100`.

Optional live mode: set `PRAXO_BASE_URL`, `PRAXO_MODEL`, and `PRAXO_API_KEY` as
needed, then run `python app.py --live`. Live mode has not been verified for this
example. The business service uses `--base-url`, separate from the model URL.

The service and cross-language tests live in
`demo-repository/shared-business-services/tests/`. Drafts are process-local,
idempotent per tenant/order/key, and lost on restart. Tokens are public fixture
credentials, not a production identity system. The service is loopback-only.
