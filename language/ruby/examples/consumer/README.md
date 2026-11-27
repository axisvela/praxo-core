# Independent Ruby Consumer

This module installs published `praxo-core` `0.10.1` and verifies an allow/deny
governed tool path without local replacements.

This is the recommended package pin, not new execution evidence. The consumer
has not been rerun against this release as part of the pin update.

```bash
bundle install
bundle exec ruby test_starter.rb
```

For a source checkout without Bundler:

```bash
ruby -I language/ruby/lib test_starter.rb
```

The starter uses a deterministic model. It does not prove live provider behavior,
authentic identity, durable approvals, or production readiness.
