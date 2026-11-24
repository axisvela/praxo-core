# Ruby supply-chain review (CY-07)

A bounded first slice of [CY-07](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/),
not a malware-detection system. It compares one fixed pinned manifest with a
registry copy and proposes a reviewed version pin. No dependency update, registry
write or proven tamper verdict.

Run from the repository root:

```bash
ruby -I language/ruby/lib language/ruby/Tutorial/supply-chain-review/app.rb --test
ruby -I language/ruby/lib language/ruby/Tutorial/supply-chain-review/app.rb
ruby -I language/ruby/lib language/ruby/Tutorial/supply-chain-review/app.rb --package pkg-200
ruby -I language/ruby/lib language/ruby/Tutorial/supply-chain-review/app.rb --simulate-failure
```

Expected test output: `Ruby CY-07 supply-chain-review tutorial: success, denial and dependency failure passed`.
Both negative commands exit nonzero.

`compare_manifests` returns `maintainer_changed=true`, `checksum_match=false` and
signals `maintainer-change`/`checksum-mismatch` for `pkg-100`; `propose_pin`
returns `version=1.2.0`, `status=draft_only`, `review_required=true` and
`auto_updates=0`. Policy limits the package and final `hold_pinned_version`
action.

Tests assert one read and one draft on success, zero reads/drafts for a
cross-package denial, and one read/zero drafts for the simulated manifest outage.
Real package verification, registry quarantine and provenance attestation belong
to the consumer.
