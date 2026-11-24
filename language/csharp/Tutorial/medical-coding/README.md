# C# medical coding (HC-04)

A bounded first slice of [HC-04](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/),
not a billing or reimbursement system. It checks fixed record completeness and
drafts review-only DRG/DIP-style codes. No false coding, reimbursement
optimization or billing submission.

## Why this language and runtime?

- **Selection basis:** An existing .NET clinical or revenue-cycle application could
  embed Core inside its own process. No hospital or billing consumer is verified.
- **Demonstrated fit:** A .NET 8 console app uses Core tools and policy checks over
  fixed fields; completeness and both codes are scripted responses.
- **Choose when:** Learning the Core seam in an already maintained C# application.
- **Do not choose when:** Expecting coding, audit or claim logic. Compare certified
  coding rules engines and existing clinical documentation workflows first.
- **Evidence limit:** Core integration fixture only; no record parsing, code
  validation, billing submission or clinical/compliance claim.

Build and run from the repository root:

```bash
dotnet build language/csharp/Tutorial/medical-coding/MedicalCoding.csproj --nologo
dotnet language/csharp/Tutorial/medical-coding/bin/Debug/net8.0/Praxo.MedicalCoding.dll --test
dotnet language/csharp/Tutorial/medical-coding/bin/Debug/net8.0/Praxo.MedicalCoding.dll
dotnet language/csharp/Tutorial/medical-coding/bin/Debug/net8.0/Praxo.MedicalCoding.dll --record record-200
dotnet language/csharp/Tutorial/medical-coding/bin/Debug/net8.0/Praxo.MedicalCoding.dll --simulate-failure
```

Expected test output:

```text
success: record-100 fields=6 missing=1 status=draft_only submissions=0 reads=1
deny: AGENT_POLICY_DENIED reads=0
failure: RECORD_UNAVAILABLE reads=1
```

`record-200` is denied by policy before the tool runs. `--simulate-failure` reads
once, reports `RECORD_UNAVAILABLE`, and exits nonzero.

`read_record` returns 6 fields with `attending` missing and 0.83 completeness for
`record-100`; `draft_codes` returns `I10`/`E11.9` with `status=draft_only`,
`review_required=true`, `billing_submissions=0` and
`reimbursement_optimizations=0`. Policy limits the record and final
`draft_codes` action.

Real clinical documentation review, coding audit and claim submission belong to
the coding and revenue-cycle teams.
