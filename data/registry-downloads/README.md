# Registry Download Metrics

Public package-registry download metrics collected by
`python -m scripts.metrics.registry_downloads`.

The collector stores:

- `snapshots/YYYY-MM-DD.json`: immutable daily snapshots;
- `latest.json`: the latest snapshot;
- `series.csv`: long-form history for language/channel analysis;
- `summary.json` and `summary.md`: the latest aggregate by language and channel.

Metrics are not adoption evidence. Registry totals can include CI, mirrors,
speculative downloads, and repeated installs. Missing values are not zero.
Provider errors and unavailable metrics are recorded explicitly.

## Commands

```bash
python -m scripts.metrics.registry_downloads
python -m scripts.metrics.registry_downloads --only npm,crates
python -m scripts.metrics.registry_downloads --report
python -m scripts.metrics.registry_downloads --check
```

The collector uses public registry APIs where they expose download counts.
PyPI uses the community `pypistats.org` aggregate because PyPI itself does not
provide a download-statistics API. Registries without a public count API are not
invented or scraped.

Do not commit generated snapshots containing provider credentials or private
data. This directory contains only public package metrics.
