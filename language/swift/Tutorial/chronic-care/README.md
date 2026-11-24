# Swift Chronic Care (HC-02)

A bounded first slice of HC-02, not a clinical decision system. It summarizes fixed
wearable trends, routes a review-only care alert and records no dosage or treatment
change. No device SDK, patient identity or live model is used.

## Why this language and runtime?

- **Selection basis:** Swift is the default for existing Apple-platform health and
  wellness apps, where review logic can stay in the app runtime.
- **Demonstrated fit:** Native Swift tools and policy return fixed trend data and a
  draft alert; the model branches only on the supplied review action.
- **Choose when:** An existing Swift/Apple health app needs a governed review seam.
- **Do not choose when:** Clinical decision support, HealthKit integration or device
  synchronization is required. Compare the care protocol and platform APIs first.
- **Evidence limit:** Fixed fixture only; no HealthKit, wearable feed, patient
  identity, dosage logic, treatment recommendation or clinical validation.

## Run

From the repository root:

```bash
swift run --package-path language/swift praxo-chronic-care-tutorial --test
swift run --package-path language/swift praxo-chronic-care-tutorial
swift run --package-path language/swift praxo-chronic-care-tutorial --patient patient-200
swift run --package-path language/swift praxo-chronic-care-tutorial --simulate-failure
```

Expected test output:

```text
Swift HC-02 chronic-care tutorial: success, denial and dependency failure passed
```

`patient-200` is denied before the read tool runs. `--simulate-failure` reads once,
fails with `TRENDS_UNAVAILABLE`, and exits nonzero.

## Local verification note

The local Windows Swift toolchain remains blocked by missing Windows SDK/MSVC
headers and a SwiftPM `.build` symbolic-link I/O error. The tutorial is wired into
CI with `swift-actions/setup-swift`; that job is added but its remote result is
unverified. No local pass is claimed.
