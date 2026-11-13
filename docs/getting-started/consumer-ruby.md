# Independent Ruby Consumer

Use published `praxo-core==0.7.0` in your own application with Ruby 3.1 or
newer. No PRAXO-CORE source checkout, API key, model service, or AxisVela product
is required. Installation needs RubyGems access or a cached gem.

This is an extended-language starter. It demonstrates the allow/deny path but is
not one of the four pilot languages that carry the governed negative matrix.

## Choose the Boundary

This is a fit for an embedded model/tool loop with explicit tool scope and
policy. Your application still owns model access, authentic identity, persistent
approvals, external effects, and isolation. It is not a hosted agent platform,
durable graph engine, or sandbox service. See [when not to use Core](when-not-to-use.md).

## Create the Application

Declare the exact dependency in a `Gemfile`:

```ruby
source 'https://rubygems.org'

gem 'praxo-core', '0.7.0'
```

Then run `bundle install`. Do not use a `path:` or `git:` source, a vendored
checkout, or a `$LOAD_PATH` entry that substitutes the published gem.

## Application Source

Use the following as `starter.rb`, rendered from the
[tested source](https://github.com/axisvela/praxo-core/blob/main/examples/consumer-ruby/starter.rb).

<!-- ruby-consumer-source: starter.rb -->

## Acceptance Tests

Use the following as `test_starter.rb`, rendered from the
[tested source](https://github.com/axisvela/praxo-core/blob/main/examples/consumer-ruby/test_starter.rb).

<!-- ruby-consumer-source: test_starter.rb -->

## Verify

```sh
bundle install
bundle exec ruby test_starter.rb
```

Expected program output:

```text
allow: recorded; effects=1
deny: policy rejected; effects=0
```

The model is a deterministic fixture, not an LLM. `allowed_tools` limits the tool
name; Policy also checks the target argument. A denied private target must never
reach the in-memory effect counter. Keep these tests when replacing the fixture
with a real adapter.

For a source checkout without Bundler, the same test runs with
`ruby -I language/ruby/lib test_starter.rb`; that path is not independent
consumer evidence.

## Scope

This starter establishes only the stated gem and fixture behavior. It does not
add the governed negative matrix, prove authentic identity, provide durable
approvals, reconcile effects, or establish isolation. Continue with the
[Ruby implementation guide](../languages/ruby/index.md) and the
[security model](../security/index.md).
