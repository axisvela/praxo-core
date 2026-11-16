# Publishing `praxo_core` to pub.dev

This page records the repository-side configuration. The final admin actions
must be performed by an uploader or publisher admin on pub.dev.

## pub.dev admin settings

Open <https://pub.dev/packages/praxo_core/admin> and configure:

| Section | Setting | Recommendation |
| --- | --- | --- |
| Package ownership | Publisher | Keep the package under the `axisvela.com` publisher. If it is still under a personal publisher, transfer it to `axisvela.com` as a publisher member. |
| Discontinued | Mark discontinued | Leave off. The package is maintained; discontinued packages disappear from normal search. |
| Unlisted | Mark unlisted | Leave off. Unlisted packages also disappear from normal search. |
| Manual publishing | Enable manual publishing | Keep enabled until one automated publish succeeds, then disable it if automated publishing is fully configured. |
| Automated publishing | GitHub Actions | Enable with repository `axisvela/praxo-core`. |
| Tag pattern | Must contain `{{version}}` | Use `dart/v{{version}}`; it matches the existing `dart/v0.6.0` source-tag shape. |
| GitHub environment | Optional hardening | Enable `pub.dev` as a required environment if tag protection alone is insufficient. |
| Google Cloud service account | Long-lived credentials | Do not use when GitHub Actions OIDC is available. |
| Version retraction | Up to 7 days after publication | Do not retract unless a release is unusable; publish a patch instead. There are currently no retracted versions. |

Only tag-triggered GitHub Actions can publish. A workflow-dispatch run verifies
the package but is not allowed by pub.dev to publish.

## Repository configuration

- Workflow: `.github/workflows/dart-release.yml`
- Package directory: `language/dart`
- Version sources: `language/dart/VERSION` and `language/dart/pubspec.yaml`
- Tag shape: `dart/vX.Y.Z`
- The tag must equal `dart/v` plus both version values.

The publish job uses the official reusable workflow
`dart-lang/setup-dart/.github/workflows/publish.yml@v1` with
`working-directory: language/dart` and OIDC (`id-token: write`). It does not use
a stored npm/pub token.

## Release sequence

1. Update `language/dart/VERSION`, `language/dart/pubspec.yaml`, and
   `language/dart/CHANGELOG.md` with the same `X.Y.Z`.
2. Run the release gates locally:

   ```bash
   cd language/dart
   dart run conformance/run.dart
   python api-snapshot.py --check
   dart run test/run.dart
   ```

3. Commit the version and changelog changes.
4. Create and push the tag:

   ```bash
   git tag dart/vX.Y.Z
   git push origin dart/vX.Y.Z
   ```

5. The `dart-release` workflow verifies the version/tag and gates, then publishes
   through OIDC. Review the Actions log and the pub.dev audit log.

Do not push a tag before the pub.dev admin tag pattern is configured. Existing
tags created before the workflow was enabled do not trigger a new publication;
use a new version tag.

## Current state

- Source version: `0.6.0`
- Published pub.dev version: `0.4.0`
- Registry status: behind source; publish the next verified version with a new
  tag rather than reusing `dart/v0.6.0`.
- Dry-run on 2026-11-16 passed conformance, API snapshot, and tests. It reported
  the previous version `0.4.0` and recommended an incremental version.
- The package ships a minimal `example/`; `examples/` is excluded from the pub
  archive via `.pubignore` and linked from the README to avoid the plural
  directory warning.

## Catching up from 0.4.0

Do not move or reuse the existing `dart/v0.5.0` and `dart/v0.6.0` tags. Choose
one release path and record it:

1. **Preserve version order (preferred):** publish `0.5.0` from tag
   `dart/v0.5.0` and `0.6.0` from tag `dart/v0.6.0` using manual publishing (or
   an explicitly authorized equivalent), then resume tag-triggered automated
   publishing from `0.7.0`.
2. **Skip to a new version:** bump source, `pubspec.yaml`, and changelog together
   to `0.6.1` or `0.7.0`, then push that new tag. pub.dev may warn about the
   skipped version but can accept a higher semantic version.

Do not publish `0.6.0` from the current branch if the tag points at different
content. Verify the tag/commit first.
