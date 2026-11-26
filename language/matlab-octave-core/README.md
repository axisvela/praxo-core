# PRAXO-CORE MATLAB/Octave shared core

Shared implementation used by the MATLAB and Octave packages. It is not a
standalone package; use the MATLAB or Octave registry entry.

## Registry and Coding-Agent Entry

- Registry introduction: [REGISTRY.md](https://github.com/axisvela/praxo-core/blob/main/language/matlab-octave-core/REGISTRY.md)
- Machine-readable entry: [llms.txt](https://github.com/axisvela/praxo-core/blob/main/language/matlab-octave-core/llms.txt) and [llms.md](https://github.com/axisvela/praxo-core/blob/main/language/matlab-octave-core/llms.md)
- Coding-agent contract: [docs/getting-started/coding-agents.md](https://github.com/axisvela/praxo-core/blob/main/docs/getting-started/coding-agents.md)
- Registry: shared source
- Community: [X](https://x.com/axisvela) · [Weibo](https://weibo.com/u/1936025761) · [LinkedIn](https://www.linkedin.com/company/axisvela/) · [Facebook](https://www.facebook.com/profile.php?id=61596905732406) · [YouTube](https://www.youtube.com/@axisvela) · [Discord](https://discord.com/channels/1575163993767809064/1575164343148875977) · [GitHub Discussions](https://github.com/axisvela/praxo-core/discussions) · [GitHub Issues](https://github.com/axisvela/praxo-core/issues) · [Documentation](https://axisvela.github.io/praxo-core/) · [Architect](https://axisvela.architect.pub)

## Service authentication

The shared service authentication sample provides a principal struct, an
injectable introspection authenticator, and a revocation client for RFC 7662
and RFC 7009.

- Module path: `language/matlab-octave-core/+praxo_service/`
- Tests: `language/matlab-octave-core/tests/test_service_auth.m`
- Transport seam: function handle `(url, form, authorization)` returning
  `struct('status', ..., 'body', ...)`; pass `''` for no authorization header.

Run from the repository root:

```bash
octave-cli --eval "addpath('language/matlab-octave-core'); addpath('language/matlab-octave-core/tests'); test_service_auth"
```

Verified under GNU Octave 11.3.0 with the existing `D:\dev` toolchain; the
shared test prints `test_service_auth passed`. Native MATLAB runtime remains
unavailable and unverified.

## Optional Java Process Host

`praxo.PluginProcess` uses Java `ProcessBuilder`, not Octave `popen2`. A working
JVM (`usejava('jvm')`) is required. Windows Octave 11.3 is locally verified;
MATLAB runtime verification remains pending.

```matlab
config = struct('plugin_id', 'com.example.echo', 'path', 'python', ...
    'args', {{'path/to/plugin.py'}});
host = praxo.PluginProcess(config);
cleanup = onCleanup(@() host.stop());
response = host.invoke('tool.provider', 'echo', '{"text":"hi"}', 5);
```

The token is generated with Java UUID and supplied through the child environment
and each request, never through command arguments. Stderr is discarded separately
from protocol output. Calls validate response ID/version and limit response size.
A response timeout terminates the child and marks the host inactive. This initial
text-payload adapter does not implement the protocol's cancel-before-kill flow,
binary payloads, or concurrent calls; do not treat it as full host parity.

`config.start_timeout` optionally sets the health-check timeout in seconds
(default 10). Invocation timeouts default to 30 seconds and must be positive,
finite scalars. Remote call errors use `praxo:pluginCall` and leave the host
active. Malformed responses, output closure, child exit, and response timeouts
terminate the child and make subsequent calls fail until a new host is created.
`stop` is idempotent, requests shutdown, waits briefly, and forcibly terminates
an unresponsive process. Constructor failures also clean up the child and pipes.

## Tutorials and Reference Applications

- [Tutorial plan](https://axisvela.github.io/praxo-core/getting-started/tutorial-plan/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-plan/)): delivery standards and the reference-application portfolio.
- [100 candidate agent scenarios](https://axisvela.github.io/praxo-core/getting-started/agent-scenarios/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/agent-scenarios/)): candidate business goals and related slices.
- [Unified Tutorial Catalog](https://axisvela.github.io/praxo-core/getting-started/tutorial-catalog/) ([中文](https://axisvela.github.io/praxo-core/zh-CN/getting-started/tutorial-catalog/)): cross-language tutorials, examples, and application paths.
- [Reference application portfolio](https://axisvela.github.io/praxo-core/project/roadmap/#reference-application-portfolio) ([中文](https://axisvela.github.io/praxo-core/zh-CN/project/roadmap/)).

