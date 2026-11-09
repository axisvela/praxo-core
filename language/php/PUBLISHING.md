# Publishing the PHP Core

## Status

The PHP package is `axisvela/praxo-core` on Packagist. Its publication source is
the split repository `axisvela/praxo-core-php`. Tag `v0.4.0` was pushed from
main-repository tag `php/v0.4.0`; `v0.3.0` and `v0.2.0` remain available.
Source `0.4.1` and `api/0.4.1.txt` are prepared; split tag `v0.4.1` and
Packagist publication are pending.

Packagist does not receive a manual upload from this repository; it reads the
split repository's Composer metadata and tags. Verify the Packagist package page
after the push/webhook delay.

## Build and test (main repository)

```bash
php language/php/conformance/run.php
php language/php/tests/run.php
php language/php/conformance/run.php --api-snapshot > language/php/api/0.4.1.txt
php language/php/conformance/run.php --check-api
```

`composer` is not installed in this environment. The PHP binary runs the local
tests and conformance checks directly.

## Publish (split repository)

```bash
gh repo clone axisvela/praxo-core-php build/praxo-core-php
cp language/php/src/*.php build/praxo-core-php/src/
cp -R language/php/src/Adapters build/praxo-core-php/src/
cp language/php/api/0.4.1.txt build/praxo-core-php/api/
```

Update the split repository `README.md` version and API snapshot reference.
Ensure its `composer.json` declares `"files": ["src/autoload.php"]` under
`autoload` and does not hardcode `version`; Packagist derives the version from
the split tag. Then:

```bash
cd build/praxo-core-php
git add -A
git commit -m "release(php): 0.4.1"
git tag -a v0.4.1 -m "praxo-core PHP 0.4.1"
git push origin main
git push origin v0.4.1
```

The split repository uses `vX.Y.Z` tags; the main repository uses
`php/vX.Y.Z` source tags.

## Credentials and configuration

- No Packagist API token is needed for the normal GitHub webhook flow.
- GitHub access uses the authenticated `gh` account
  (`gh auth status`).
- `composer` is not installed locally; package-registry ingestion is performed
  by Packagist after the split repository push.
- The split repository is a publication mirror. The main repository remains the
  source of truth for conformance, tests, and API snapshots.

## Verify

Check the split repository tag:

```bash
gh api repos/axisvela/praxo-core-php/tags --jq '.[].name'
```

Check the Packagist package versions page, then:

```bash
composer require axisvela/praxo-core:^0.4
```
