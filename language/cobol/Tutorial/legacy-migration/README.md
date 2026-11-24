# COBOL Legacy Migration Inventory (SE-03)

Inventories three fixed modules and reports activation and batch counts. No code
conversion or production migration.

## Why this language and runtime?

- **Selection basis:** The module inventory lives beside an existing COBOL estate;
  keeping the read-only analysis in COBOL matches the source system.
- **Demonstrated fit:** A line-sequential COBOL program parses module records and
  writes a deterministic inventory (`total=3 active=2 batch=2`).
- **Choose when:** Establishing a read-only baseline before a migration review.
- **Do not choose when:** Seeking an automatic converter or production cutover.
  Compare source analysis tools and the migration plan first.
- **Evidence limit:** Three fixed records and a local GnuCOBOL run only; not z/OS,
  CICS, IMS or a migration proof.

## Run

With GnuCOBOL `cobc` on `PATH` or `COBC` set:

```bash
python language/cobol/Tutorial/legacy-migration/run.py
```

Expected output:

```text
module=CUSTMAIN kind=CICS status=ACTIVE lines=01200
module=BILLCALC kind=BATCH status=ACTIVE lines=00800
module=RPTGEN kind=BATCH status=RETIRED lines=00300
total=0003 active=0002 batch=0002
COBOL SE-03 legacy migration tutorial: passed (inventory only, no migration)
```

No source conversion, deployment or production change is implemented.
