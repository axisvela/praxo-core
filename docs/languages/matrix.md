# Language Support Matrix

This table covers all languages in the [normative support matrix](https://github.com/axisvela/praxo-core/blob/main/spec/languages.md), including planned and consumer-gated entries. It is generated from that file during the site build, so status, source tags, and scope have one source of truth.

**Target:** independently implemented, native-capable languages target Framework. Wire is an intermediate stage unless an explicit documented language/runtime limitation prevents Framework support. Bridge and Sample describe the current delivery form; they do not by themselves establish a permanent limitation. A named consumer and maintainer are required before implementing a new native loop.

**How to read status:** `released` means a source release, not publication to a package registry or proof of production readiness. `in progress` is not a release. `planned` and `consumer-gated` are not commitments to a delivery date. Source tags are independent of the shared `SPEC_VERSION`; `none` means no tag is claimed.

The notes report declared scope and evidence, not a promise of full Go feature parity. C's current public API is wire-level despite its historical Core classification. For exact CI jobs and tier gates, see the [canonical matrix](https://github.com/axisvela/praxo-core/blob/main/spec/languages.md) and [implementation support policy](support.md).

<!-- language-support-matrix -->
