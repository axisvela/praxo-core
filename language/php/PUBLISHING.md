# PHP Package Artifacts

The canonical source is `language/php/` in `axisvela/praxo-core`. Packagist reads
`axisvela/praxo-core-php` tags, not this directory. Main-repository source tags use
`php/vX.Y.Z`; split tags use `vX.Y.Z`. The split Composer metadata must omit
`version` so Packagist derives it from the tag.

## Published Defect

Packagist `axisvela/praxo-core` 0.10.1 is broken: split tag `v0.10.1` contains
`src/autoload.php` requiring `src/PluginProcessHost.php`, but omits that file.
CI run `46030983730` installed that version successfully, then failed at Composer
autoload time. The canonical file exists.
This is an incomplete split artifact, not an optional feature or a PHP version
problem. Do not guard the require, remove the feature, or rewrite the old tag.
A new patch release is required; local staging does not repair published 0.10.1.

## Local Gates

Run from the canonical repository root:

```sh
php language/php/conformance/run.php
php language/php/conformance/run.php --check-api
php language/php/tests/run.php
php language/php/tests/plugin_process.php
python scripts/build_php_package.py --output build/php-split
python scripts/build_php_package.py --output build/php-split --check
python scripts/test_php_package.py
```

The builder requires a new or empty output directory and never overwrites a
checkout. It recursively copies all runtime sources and API snapshots, plus the
package license, changelog and public discovery documents. Composer metadata is
derived from canonical `composer.json`, removing only the hardcoded version and
canonical-only test scripts. Conformance depends on the main repository's shared
spec vectors; it is deliberately not advertised as runnable in the runtime split.
Examples and tutorials remain linked canonical sources, not split runtime files.
The checker compares the complete artifact file inventory and bytes, ignoring
only `.git` metadata; missing, modified, stale, and symlinked files fail.

For a clean standalone clone of `axisvela/praxo-core-php`, `--sync-split` replaces
only the managed runtime payload (`src/`, `api/`, package documents, and
`composer.json`), removing stale managed files while preserving examples,
tutorials, tests, and other published split content. It refuses a different origin,
symlinks, local edits, and untracked/ignored files. It never creates a commit, tag,
or push. Always review the resulting diff and run `--check` before publication.

The packaging tests require PHP and Composer on PATH, or `PRAXO_PHP` and
`PRAXO_COMPOSER` set to their executable paths (`composer.phar` is supported).
They install a staged split via a Composer path repository with mirroring, not
symlinking, and disable Packagist. The consumer runs outside the checkout after
the staged source has been deleted. It requires `vendor/autoload.php`, checks
plugin-host classes, verifies allow with one side effect and deny with none,
then removes the installed plugin-host file and requires the same consumer to
fail. There is no canonical source fallback available there.

Set `PRAXO_PYTHON` to the Python executable for the process-plugin test if Python
is not on PATH. The packaging tests accept PHP options through `PRAXO_PHP_ARGS`
when an installation needs explicit extension configuration. Keep Composer TLS
verification enabled. No credentials or live providers are needed for these gates.

Composer discovery metadata includes the `praxocore` alias and Laravel, for
which canonical host applications exist. Drupal is planned, not a demonstrated
integration, and is intentionally not a package keyword.

## Publication Boundary

The builder and tests do not publish packages. A corrected artifact requires a
new patch release with aligned version metadata, API snapshot, and changelog;
immutable `0.10.1` must not be retagged. Stage the complete payload rather than a
hand-selected set of PHP files, and check it before publication.

The `php-package` CI job runs staging, integrity, and isolated Composer consumer
regressions with PHP and Composer. Keep the separate Packagist consumer check so
an incomplete or stale publication still fails visibly. After registry ingestion,
verify the exact new version from a fresh `--prefer-dist` consumer with no path
repository or canonical fallback, including allow/deny and plugin-class checks
through `vendor/autoload.php`. A local staged install is not registry acceptance.
