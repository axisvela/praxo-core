# Human-in-the-loop Interrupts

This example configures `TPraxoAgentOptions.InterruptOn` and
`OnInterruptDecision` for approve, edit-with-reauthorization, and respond
decisions. It is a deterministic self-check: the tool is a local echo and the
model is scripted.

Run from the repository root:

```bash
mkdir -p build/delphi
fpc -Mobjfpc -Scghi -Fulanguage/delphi -FEbuild/delphi language/delphi/examples/hitl/hitl.pas
./build/delphi/hitl
```

On Windows use `build\delphi\hitl.exe`.

Expected output:

```text
Delphi HITL example passed
```

An edited decision replaces the call arguments and re-runs the configured
`Authorize` hook. A rejected decision raises `AGENT_APPROVAL_DENIED` without
invoking the tool. A respond decision skips the tool and feeds the encoded
response back to the model. Missing handlers raise
`AGENT_INTERRUPT_UNHANDLED`; malformed decisions raise
`AGENT_INTERRUPT_DECISION_INVALID`. The full approve, edit-denial, reject,
respond, unhandled, and invalid matrix lives in `tests/hitl_tests.lpr`.
