# PRAXO-CORE for GNU Octave

Native Octave Core for the PRAXO-CORE agent framework. This package contains
the `+praxo` namespace and the MIT-licensed Core implementation.

## Install

```octave
pkg install https://github.com/axisvela/praxo-core/releases/download/octave/v0.2.1/praxo-core-0.2.1.tar.gz
pkg load praxo-core
```

For the Octave Packages index:

```octave
pkg install -forge praxo-core
pkg load praxo-core
```

## API

```octave
node = praxo.parse_json('{"name":"echo","input":{"text":"hi"}}');
raw = praxo.encode_json(node);
call = praxo.parse_tool_call(raw);
paths = praxo.validate_schema(praxo.parse_json('{"type":"string"}'), node);
[valid, manifest] = praxo.validate_manifest('{}');
```

The package passes all eleven shared conformance vector groups under GNU Octave
11.3.0. It includes the native agent loop, memory, checkpoints, lexical path
policy, context compaction, event sinks, middleware helpers, and tool
selection.

## Scope

The Core does not call Go or another language runtime. Provider adapters,
process bridges, and plugin hosts are outside the declared Core scope. MATLAB
compatibility is a target, not independently verified by this package.

## Links

- Main repository: https://github.com/axisvela/praxo-core
- Octave documentation: https://axisvela.github.io/praxo-core/languages/matlab/
- License: MIT
