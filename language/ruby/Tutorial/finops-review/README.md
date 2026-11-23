# Ruby FinOps Review (SE-07)

A bounded first slice of [SE-07](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/),
not autonomous multi-cloud governance. This uses the native Ruby Core in source
mode. No cloud credentials, remote services, new Core APIs or additional gems
are required. Ruby must already be installed.

Run from the repository root:

```bash
ruby -I language/ruby/lib language/ruby/Tutorial/finops-review/app.rb --test
ruby -I language/ruby/lib language/ruby/Tutorial/finops-review/app.rb
ruby -I language/ruby/lib language/ruby/Tutorial/finops-review/app.rb --account cloud-200
ruby -I language/ruby/lib language/ruby/Tutorial/finops-review/app.rb --simulate-failure
```

Expected test output: `Ruby SE-07 FinOps tutorial: success, denial and dependency failure passed`.
The two negative commands exit nonzero. The test asserts denied accounts have
zero reads/drafts; a failed cost read has one read and zero drafts.

The deterministic model plans a read, consumes the tool-computed candidate, then
requests a scoped review draft and consumes that result. Application-owned state
counts reads and drafts per run; it is ephemeral, not persistent memory.
The native tool selects the highest-cost resource below 5% utilization from two
synthetic records. `vm-idle` costs `0.5 * 24 * 30 = 360` in a fixed thirty-day
simulation. This is estimated cost exposure, not verified savings. Policy limits
both account and final draft resource/action. The draft requires review and has
`cloud_writes=0`; there is no cloud mutation tool.

Real inventory, pricing, business-critical exclusions, approval identity,
idempotency, effect reconciliation and resource shutdown belong to the consumer.
No live provider, publication install, independent consumer, cloud API or
production verification is claimed. The model is scripted, not evidence of
autonomous resource discovery or optimization.
