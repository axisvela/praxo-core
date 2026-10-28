# Language Core Source

Independent implementations of the PRAXO-CORE contract live in this directory.
Go remains the reference implementation at the repository root.

Start with the [Core directory](../docs/languages/index.md) for language-specific
installation, build instructions, and limitations, or the
[language matrix](../spec/languages.md) for declared scope and source tags.

Bridge wrappers live in [`bindings/`](../bindings/README.md). JavaScript,
Kotlin, and Scala are [samples](../examples), not independent implementations.
Visual Basic continues to consume the C# Core implementation under `csharp/samples/`.

See [repository layout and source migration](../docs/project/repository-layout.md)
if your scripts previously used root-level language directories. Package names,
Go imports, contract versions, and existing source tags are unchanged.
