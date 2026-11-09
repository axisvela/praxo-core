# Independent PHP Consumer

This module installs published `axisvela/praxo-core` `0.4.0` and verifies an
allow/deny governed tool path without local replacements.

```bash
composer install
composer test
```

For a source checkout without Composer, the starter falls back to
`language/php/src/autoload.php`:

```bash
php test_starter.php
```

The starter uses a deterministic model. It does not prove live provider behavior,
authentic identity, durable approvals, or production readiness.
