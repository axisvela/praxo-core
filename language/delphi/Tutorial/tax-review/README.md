# Delphi Tax Review (FC-04)

A bounded tax-planning tutorial. It reads a fixed ledger, computes taxable income
and tax due, then drafts a review-only filing. No filing is submitted and no tax
advice is given.

## Why this language and runtime?

- **Selection basis:** Delphi and Free Pascal remain in long-lived finance and
  desktop accounting systems where ledger rules already live.
- **Demonstrated fit:** Fixed revenue 100000 and deductions 15000 produce taxable
  85000 and tax due 17000 at 20%; the draft reports zero submissions.
- **Choose when:** An existing Delphi accounting application needs a governed review
  step without replacing its runtime.
- **Do not choose when:** Filing, tax advice or a modern web tax platform is required.
  Compare the filing system and qualified tax review first.
- **Evidence limit:** One fixed ledger and rate only; no tax code engine, filing,
  payment, audit trail or jurisdiction rules.

## Run

From `language/delphi`:

```bash
fpc -Mobjfpc -Scghi -O2 -Fu. -FEbuild Tutorial/tax-review/tax.pas
./build/tax --test
./build/tax
./build/tax --return return-200
./build/tax --simulate-failure
```

Expected test output:

```text
success: return-100 taxable=85000 tax_due=17000 status=draft_only submissions=0 reads=1
deny: AGENT_POLICY_DENIED reads=0
failure: LEDGER_UNAVAILABLE reads=1
```

`return-200` is denied before the ledger tool runs. `--simulate-failure` reads once,
reports `LEDGER_UNAVAILABLE`, and exits nonzero.
