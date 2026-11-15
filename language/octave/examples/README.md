# Octave Examples

Octave shares the Core implementation and examples in
`language/matlab-octave-core/+praxo` and `language/matlab/examples`.

- [`consumer/`](consumer/): thin runner for the shared deterministic allow/deny
  governed tool path.
- [`live-model/`](live-model/): thin runner for the shared OpenAI-compatible
  `get_time` example.

Both wrappers add `language/matlab-octave-core` and the corresponding
`language/matlab/examples/<name>` directory to the interpreter path.

Run from the repository root:

```bash
octave-cli language/octave/examples/consumer/run.m
octave-cli language/octave/examples/live-model/run.m
```
