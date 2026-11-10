# Independent PHP Consumer

Use published `axisvela/praxo-core` `0.4.1` in your own application with PHP 8.2
or newer and Composer 2. No PRAXO-CORE source checkout, API key, model service,
or AxisVela product is required. Installation needs Packagist access or a cached
Composer archive.

This is an extended-language starter. It demonstrates the allow/deny path but is
not one of the four pilot languages that carry the governed negative matrix.

## Choose the Boundary

This is a fit for an embedded model/tool loop with explicit tool scope and
policy. Your application still owns model access, authentic identity, persistent
approvals, external effects, and isolation. It is not a hosted agent platform,
durable graph engine, or sandbox service. See [when not to use Core](when-not-to-use.md).

## Create the Application

Declare the exact dependency in `composer.json`:

```json
{
  "require": {
    "axisvela/praxo-core": "0.4.1"
  }
}
```

Then run `composer install`. Do not use a `path` repository, a local archive, or
an `autoload.php` include from a source checkout for acceptance.

## Application Source

Use the following as `starter.php`, rendered from the
[tested source](https://github.com/axisvela/praxo-core/blob/main/examples/consumer-php/starter.php).

<!-- php-consumer-source: starter.php -->

## Acceptance Tests

Use the following as `test_starter.php`, rendered from the
[tested source](https://github.com/axisvela/praxo-core/blob/main/examples/consumer-php/test_starter.php).

<!-- php-consumer-source: test_starter.php -->

## Verify

```sh
composer install
composer test
```

Expected program output:

```text
allow: recorded; effects=1
deny: policy rejected; effects=0
```

The model is a deterministic fixture, not an LLM. `allowedTools` limits the tool
name; Policy also checks the target argument. A denied private target raises
`PraxoException` with code `AGENT_POLICY_DENIED` and must not increment the
in-memory counter. Keep these tests when replacing the fixture with a real
adapter.

For a source checkout without Composer, the starter falls back to
`language/php/src/autoload.php`; that path is not independent consumer evidence.

## Scope

This starter establishes only the stated package and fixture behavior. It does
not add the governed negative matrix, prove authentic identity, provide durable
approvals, reconcile effects, or establish isolation. Continue with the
[PHP implementation guide](../languages/php/index.md) and the
[security model](../security/index.md).
