# PHP Reference Applications

Two PHP reference applications use the published `axisvela/praxo-core:0.8.1`
package and a Laravel 12 host. They are not the Core package itself and do not
change the PHP Core API.

| Directory | Purpose | Status |
| --- | --- | --- |
| `content-review/` | Host-integration precursor: review one existing article and draft a review-only publication | Deterministic local tests pass; not AI-native |
| `ai-editorial-studio/` | AI-native reference application: brief -> retrieve -> generated draft, taxonomy and SEO -> review-only publication request | Deterministic local tests pass; CI job added but not run |

The AI-native app is the reference direction. The precursor is retained for host
plumbing comparison. Neither app publishes to a CMS from the agent path.

## Run

```bash
cd language/php/application/content-review
composer install --no-interaction --prefer-dist
vendor/bin/phpunit

cd ../ai-editorial-studio
composer install --no-interaction --prefer-dist
vendor/bin/phpunit
```

Drupal is the next PHP host for the AI-native workflow. Drupal core is an external
GPL dependency and is not vendored into this MIT repository.

See [`../../../../docs/project/ai-native-reference-applications.md`](../../../../docs/project/ai-native-reference-applications.md)
for the AI-native acceptance criteria and scenario map.
