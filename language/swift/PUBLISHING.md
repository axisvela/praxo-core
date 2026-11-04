# Publishing the Swift Core

## Status

Source tag `swift/v0.2.0` maps to library `PraxoCore` version `0.2.0`. The
SPM mirror `axisvela/praxo-core-swift` publishes plain tag `0.2.0`. Swift
Package Index listing PR:
<https://github.com/SwiftPackageIndex/PackageList/pull/16032>.

## Important packaging constraint

Swift Package Manager expects `Package.swift` at the repository root and
semantic-version tags such as `0.2.0`. This monorepo keeps the package under
`language/swift` and uses the prefixed source tag `swift/v0.2.0`, so it cannot
be consumed directly as an SPM dependency.

## Split repository

The mirror is `axisvela/praxo-core-swift` and contains:

- `Package.swift`
- `Sources/`
- `Tests/`
- `LICENSE`
- `README.md`

Tag the mirror with plain semantic versions (`0.2.0`, `0.2.1`, ...), not
`swift/vX.Y.Z`. Consumers then use:

```swift
.package(url: "https://github.com/axisvela/praxo-core-swift.git", from: "0.2.0")
```

## Swift Package Index

No separate account is required. Submit the mirror URL in a pull request to
<https://github.com/SwiftPackageIndex/PackageList>. The index runs its own build
checks against the semver tag.

## Verify

```bash
swift package resolve
swift test
swift run praxo-conformance
```
