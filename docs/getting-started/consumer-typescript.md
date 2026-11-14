# Independent TypeScript Consumer

Use the published `@axisvela/praxo-core@0.6.0` package in your own Node.js
application. Node.js 20 or newer is required. No PRAXO-CORE source checkout, API
key, model service, or AxisVela product is needed. Installation needs npm
registry access or a populated cache.

## Choose the Boundary

This fits an embedded model/tool loop with explicit tool scope and policy. Your
application still owns model access, authentic identity, persistent approvals,
external effects, and isolation. It is not a hosted agent platform, durable
graph engine, or sandbox service. See [when not to use Core](when-not-to-use.md).

## Create the Application

In a new application directory, create `package.json` with an exact dependency,
then install from the lockfile:

```sh
npm install --save-exact @axisvela/praxo-core@0.6.0
```

Commit the generated `package-lock.json`, and use `npm ci` in repeatable checks.
Do not use `file:`, `link:`, a repository URL, or a local path to substitute the
package. The tests verify the pinned version and that the module resolves inside
the application.

## Application Source

Use the following as `starter.js`, rendered directly from the
[tested source](https://github.com/axisvela/praxo-core/blob/main/language/typescript/examples/consumer/starter.js).

<!-- typescript-consumer-source: starter.js -->

## Acceptance Tests

Use the following as `test_starter.test.js`, rendered from the
[tested source](https://github.com/axisvela/praxo-core/blob/main/language/typescript/examples/consumer/test_starter.test.js).

<!-- typescript-consumer-source: test_starter.test.js -->

## Verify

```sh
npm ci --no-audit --no-fund
npm test
node starter.js
```

Expected program output:

```text
allow: recorded; effects=1
deny: policy rejected; effects=0
```

The model is a deterministic fixture, not an LLM. `allowedTools` limits the tool
name; Policy also checks the target argument. A denied call throws
`PolicyDeniedError` and must not increment the in-memory counter. An empty
allowlist is not deny-all in the current API. Keep these tests when replacing
the fixture with a real model adapter.

## Governed Acceptance

`governed.test.js` adds five negative checks:

```sh
node --test governed.test.js
```

| Check | Required outcome |
| --- | --- |
| Missing mandatory policy | application guard rejects before a run; zero tool effects |
| Empty tool scope | application guard rejects; zero tool effects |
| Middleware changes final arguments | final operation is reauthorized; denial prevents the effect |
| Approval edit changes arguments | edited operation is reauthorized; denial prevents the effect |
| Policy service error | run fails closed; zero tool effects |

Use the
[tested source](https://github.com/axisvela/praxo-core/blob/main/language/typescript/examples/consumer/governed.test.js).
The guard is application-level: Core keeps its ordinary nil-policy behavior.
These checks do not prove authentic identity, durable approvals, effect
reconciliation, or a general security profile.

These checks establish only the stated package and fixture behavior, not live
model quality, authentic identity, isolation, durable effects, or production
safety. Continue with the [TypeScript implementation guide](../languages/typescript/index.md)
and the [security model](../security/index.md).
