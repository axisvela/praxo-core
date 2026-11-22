# Perl Log Triage

A small operations tutorial using the native Perl Core. The Agent has one fixed
tool, `summarize_log`, which reads the tutorial's own log fixture and returns
severity counts. The deterministic model then returns a structured report with
an empty `mutating_actions` list. It does not read arbitrary files, execute shell
commands, send alerts, or change the log.

## Run

From the repository root:

```bash
perl language/perl/Tutorial/log-triage/triage.pl
```

Output:

```json
{"log":{"errors":2,"first_error":"2026-11-22T10:00:05Z ERROR payment timeout","info":2,"source":"fixture","warnings":1},"mutating_actions":[]}
```

## Failure Checks

```bash
perl language/perl/Tutorial/log-triage/triage.pl --log other
perl language/perl/Tutorial/log-triage/triage.pl --simulate-failure
perl language/perl/Tutorial/log-triage/triage.pl --test
```

The first request is rejected by Agent policy before the tool runs (`reads=0`).
The second simulates an unavailable log dependency after one read attempt
(`reads=1`) and exits nonzero. Neither path writes a report as if it succeeded.
The `--test` mode covers success, denial and dependency failure.

## Boundaries

- This uses the native Perl Core and its source modules, not a remote Agent loop.
- The tool path is fixed to `fixture.log`; no model-selected path or shell.
- The fixture is synthetic teaching data, not a production log pipeline.
- There is no live model, provider credential, alert delivery, durable report,
  scheduler, retention policy or independent consumer evidence.
- Rules count severity, but they do not establish incident root cause or
  production operational readiness.
