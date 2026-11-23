# C# healthcare scheduling

A native C# Core tutorial for review-only appointment scheduling. It reads a fixed
`appointment-100` clinic schedule, checks slot availability, and drafts a booking
for human review with zero schedule writes. This tutorial does not write the
schedule, confirm the booking, use patient identity or call a live model.

## Run

From the repository root:

```bash
dotnet build language/csharp/Tutorial/healthcare-scheduling/HealthcareScheduling.csproj --nologo
dotnet language/csharp/Tutorial/healthcare-scheduling/bin/Debug/net8.0/Praxo.HealthcareScheduling.dll --test
dotnet language/csharp/Tutorial/healthcare-scheduling/bin/Debug/net8.0/Praxo.HealthcareScheduling.dll
dotnet language/csharp/Tutorial/healthcare-scheduling/bin/Debug/net8.0/Praxo.HealthcareScheduling.dll --appointment appointment-200
dotnet language/csharp/Tutorial/healthcare-scheduling/bin/Debug/net8.0/Praxo.HealthcareScheduling.dll --simulate-failure
```

Expected test output:

```text
C# healthcare-scheduling tutorial: all checks passed
```

`appointment-200` is denied by policy before the schedule tool runs and exits
non-zero. A simulated scheduling dependency fails after one read.

## Path

1. `read_schedule` returns slot `slot-100`, clinician `dr-7`, date `2026-12-01`,
   `available=true` and two existing bookings for `appointment-100`.
2. `draft_booking` returns `status=draft_only`, `review_required=true` and
   `booking_writes=0` for `reserve_slot`.
3. The deterministic model packages the schedule and draft into a JSON report;
   `RequirePolicy` and `RequireToolScope` are set explicitly.

The application owns patient identity, eligibility, clinician confirmation,
persistence and any real schedule write.

## Scope

This is source and local fixture evidence. It does not establish a real scheduling
system, patient record, clinical safety check, live provider, public hosting or
independent adoption. The tools and report fields are tutorial-local and are not
Core or wire API.
