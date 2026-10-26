# PRAXO-CORE Perl SDK

Perl 5.20+ implementation of the PRAXO-CORE agent contract. The normative
contract is [`spec/`](../spec/README.md); Go remains the reference
implementation.

- `SPEC_VERSION`: `0.2.0`
- SDK version: `0.1.0`
- Tier: core
- License: MIT
- Dependencies: Perl core modules only (`JSON::PP`, `File::Spec`, `Cwd`)

## Scope

The SDK implements all eleven vector groups: toolcall, JSON Schema, plugin,
memory, event, stream, checkpoint, policy, context, middleware, and the agent
loop. It includes a public API snapshot and a dependency-free test runner.

## Build and test

```bash
perl perl/conformance/run.pl
perl perl/api-snapshot.pl --check
perl perl/tests/run.pl
```

## Quickstart

```perl
use lib 'perl/lib';
use Praxo::Models ();
use Praxo::Agent ();

my $model = Praxo::Agent::StaticModel->new('hello');
my $options = Praxo::Agent::AgentOptions->new($model);
my $result = Praxo::Agent::run_agent(
    $options,
    Praxo::Models::session(id => 'demo'),
    'hello',
);
print $result->{output};
```

Tools register on the options object:

```perl
use Praxo::Agent ();

my $registry = Praxo::Agent::ToolRegistry->new;
$registry->register(Praxo::Agent::FuncTool->new('echo', 'Echo arguments', sub {
    return $_[0];
}));

my $options = Praxo::Agent::AgentOptions->new($model);
$options->{tools} = $registry;
$options->{max_steps} = 8;
```

## Layout

- `lib/Praxo/` package source.
- `conformance/run.pl` vector runner.
- `api-snapshot.pl` and `api/` public API snapshot.
- `tests/run.pl` test suite.

## Release

Tag shape: `perl/v0.1.0`. The tag targets `SPEC_VERSION` `0.2.0`.
