# Independent PHP Consumer

This module installs published `axisvela/praxo-core` `0.4.0` and verifies an
allow/deny governed tool path without local replacements.

```bash
composer install
composer test
```

Published `0.4.0` does not list its bundled `src/autoload.php` in Composer
metadata. The starter requires that package file when `Praxo\Core\Model` is not
already loaded; the next PHP package release declares it via `autoload.files`.

For a source checkout without Composer, the starter falls back to
`language/php/src/autoload.php`:

```bash
php test_starter.php
```

The starter uses a deterministic model. It does not prove live provider behavior,
authentic identity, durable approvals, or production readiness.
