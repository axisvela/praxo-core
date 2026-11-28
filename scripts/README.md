# Scripts

Internal automation for CI, release verification, discovery metadata, labs, and
language-specific package checks. Run Python entry points as modules from the
repository root:

```bash
python -m scripts.ci.ci_changes
python -m scripts.ci.sync_ci_routing --check
python -m scripts.discovery.sync_language_registry_docs --check
python -m scripts.languages.php.build_php_package --output build/php-split
```

Run tests from the repository root so package imports resolve:

```bash
python -m unittest discover -s scripts -t . -p "test_*.py"
```

## Layout

| Directory | Responsibility |
| --- | --- |
| `ci/` | Change classification, workflow routing, coverage, routing tests |
| `labs/` | Behavior and compatibility labs, runtime suites |
| `release/` | Release metadata, manifest, verification, PowerShell tools |
| `discovery/` | Docs hooks, registry/discovery generators, mirror sync, tutorial catalog |
| `checks/` | Cross-language read-only checks and their tests |
| `languages/` | PHP and OCaml package builders, package tests, package README |
| `consumers/` | Go/Python/Java/TypeScript consumer, upgrade, recipe, long-running checks |
| `execution/` | Execution-correctness runner, report, inventory, tests |
| `validation/` | Documentation, layout, roadmap, and design-doc validation |

## Conventions

- Python files use `snake_case`; PowerShell files use `kebab-case`.
- Tests use the `test_` prefix and live with their domain.
- Shared libraries are imported as `scripts.<domain>.<module>`.
- New workflow path filters should use directory globs for script groups where
  possible.
- Keep generated workflows aligned with `python -m scripts.ci.sync_ci_routing`.
