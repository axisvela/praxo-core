# COBOL Tutorials

Application tutorials live in `Tutorial/`, alongside focused `examples/`.

- [Bank batch exception review](batch-exception-review/README.md): reuse the
  existing deterministic batch handoff fixture; a separate COBOL review worker
  handles public/private records, with unavailable and timeout paths.

COBOL tutorials keep the main batch deterministic. Review is a separate,
application-owned step, not an inline model decision in the posting path.
