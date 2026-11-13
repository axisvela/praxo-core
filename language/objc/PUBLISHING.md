# Publishing the Objective-C Core

## Status

Source tag `objc/v0.4.0` maps to CocoaPods pod `PraxoCore` version `0.4.0`.
The pod is not yet published. Publication is deferred until a macOS/Xcode
environment and a configured CocoaPods Trunk token are available.

## CocoaPods

CocoaPods Trunk uses email registration, not a web account:

```bash
pod trunk register releases@axisvela.com 'AxisVela' \
  --description='PRAXO-CORE release maintainer'
pod trunk push language/objc/PraxoCore.podspec
```

The podspec uses the main repository tag and includes `Praxo*.{h,m}` from
`language/objc`. Validate it before pushing:

```bash
pod spec lint language/objc/PraxoCore.podspec
```

CI publication uses `.github/workflows/cocoapods-release.yml`. Configure the
GitHub environment `cocoapods` and repository secret
`COCOAPODS_TRUNK_TOKEN`. Do not commit the token.

## Swift Package Manager

SPM requires `Package.swift` at the repository root. See
[`language/swift/PUBLISHING.md`](../swift/PUBLISHING.md) for the split-repository
flow.

## Verify

```bash
pod install
```

or inspect the pod page at <https://cocoapods.org/pods/PraxoCore>.
