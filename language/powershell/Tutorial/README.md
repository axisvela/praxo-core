# PowerShell Tutorials

Application tutorials live in `Tutorial/`, alongside focused `examples/`.

- [Windows diagnostics](windows-diagnostics/README.md): read-only service and
  disk checks, native PowerShell commands, scoped tools, and a structured report.

PowerShell uses the shared C# Core through its module, not a separately
implemented agent loop. Fixture mode is portable; local machine checks require
Windows and do not execute repairs or arbitrary model-generated commands.
