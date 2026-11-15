# Human-in-the-loop Interrupts

This example configures `options.interruptOn`, `options.onInterruptDecision`,
and `options.onInterrupt` for approve, edit-with-reauthorization, reject, and
respond decisions. It is a deterministic self-check: the tool is a local echo
and the model is scripted.

```bash
octave-cli --path language/matlab-octave-core \
  --path language/matlab/examples/hitl --eval hitl_example
```

Expected output:

```text
MATLAB HITL example passed
```

An edited decision replaces the call arguments and re-runs the configured
policy hook. A rejected decision returns `AGENT_APPROVAL_DENIED` without
invoking the tool. A respond decision skips the tool and feeds the encoded
response back to the model. Missing handlers use `AGENT_INTERRUPT_UNHANDLED`;
malformed decisions use `AGENT_INTERRUPT_DECISION_INVALID`. The full approve,
edit-denial, reject, respond, unhandled, and invalid matrix lives in
`language/matlab-octave-core/tests/test_hitl.m`.
