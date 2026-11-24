# C# airport recovery (TL-07)

A bounded first slice of [TL-07](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/),
not an airport operations system. It reads fixed gate/crew/connection constraints
and drafts review-only recovery options. No operational scheduling, live
disruption feed or latency guarantee.

## Why this language and runtime?

- **Selection basis:** An existing .NET operations application could embed Core
  alongside its services. No airline or airport consumer is verified here.
- **Demonstrated fit:** A .NET 8 console application uses the published Core package,
  fixture tools and a policy hook; recovery options are preselected.
- **Choose when:** Evaluating the Core seam in an already maintained C# application.
- **Do not choose when:** Selecting a scheduling solver or operational recovery
  system. Compare established scheduling libraries or deterministic rules first.
- **Evidence limit:** Core integration only; no solver, ASP.NET entry, crew-legality
  validation or airport-system integration is exercised.

Build and run from the repository root:

```bash
dotnet build language/csharp/Tutorial/airport-recovery/AirportRecovery.csproj --nologo
dotnet language/csharp/Tutorial/airport-recovery/bin/Debug/net8.0/Praxo.AirportRecovery.dll --test
dotnet language/csharp/Tutorial/airport-recovery/bin/Debug/net8.0/Praxo.AirportRecovery.dll
dotnet language/csharp/Tutorial/airport-recovery/bin/Debug/net8.0/Praxo.AirportRecovery.dll --flight flight-200
dotnet language/csharp/Tutorial/airport-recovery/bin/Debug/net8.0/Praxo.AirportRecovery.dll --simulate-failure
```

Expected test output:

```text
success: flight-100 delay_min=40 crew_ok=false status=draft_only commands=0 reads=1
deny: AGENT_POLICY_DENIED reads=0
failure: AIRPORT_INDEX_UNAVAILABLE reads=1
```

`flight-200` is denied by policy before the tool runs. `--simulate-failure` reads
once, reports `AIRPORT_INDEX_UNAVAILABLE`, and exits nonzero.

`read_constraints` returns 3 gates, `crew_ok=false`, 2 connections and a 40-minute
delay for `flight-100`; `draft_recovery` returns two options with
`status=draft_only`, `review_required=true`, `schedule_commands=0` and
`latency_claims=0`. Policy limits the flight and final `draft_recovery` action.

Real airport operations, crew legality and schedule execution belong to the
airline and airport.
