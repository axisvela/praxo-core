# Language SDKs

PRAXO-CORE keeps one normative contract in [`spec/`](https://github.com/axisvela/praxo-core/tree/main/spec).
Each SDK ships its own conformance runner and declares the contract version it
targets.

## Design and Roadmap

- [Multilingual SDK design](17-multilingual-sdk.md)
- [Multilingual roadmap](18-multilingual-roadmap.md)
- [Language expansion plan](19-language-expansion.md)
- [Canonical language matrix](https://github.com/axisvela/praxo-core/blob/main/spec/languages.md)

## Core SDKs

| Language | Documentation | Tier | Status |
| --- | --- | --- | --- |
| Go | [Repository](https://github.com/axisvela/praxo-core) | Core (reference) | released |
| Python | [Python SDK](https://github.com/axisvela/praxo-core/tree/main/python) | Core | released |
| TypeScript | [TypeScript SDK](https://github.com/axisvela/praxo-core/tree/main/typescript) | Core | released |
| Java | [Java SDK](https://github.com/axisvela/praxo-core/tree/main/java) | Core | released |
| Rust | [Rust SDK](https://github.com/axisvela/praxo-core/tree/main/rust) | Core | released |
| C | [C SDK](https://github.com/axisvela/praxo-core/tree/main/c) | Core | released |
| C# | [C# SDK](https://github.com/axisvela/praxo-core/tree/main/csharp) | Core | released |
| PHP | [PHP SDK](https://github.com/axisvela/praxo-core/tree/main/php) | Core | released |
| Swift | [Swift SDK](https://github.com/axisvela/praxo-core/tree/main/swift) | Core | released |
| Julia | [Julia SDK](https://github.com/axisvela/praxo-core/tree/main/julia) | Core | released |
| R | [R SDK](https://github.com/axisvela/praxo-core/tree/main/r) | Core | released |

## Wire and Bridge SDKs

| Language | Documentation | Tier | Status |
| --- | --- | --- | --- |
| Haskell | planned | Wire | planned |
| Shell | [Shell bridge](https://github.com/axisvela/praxo-core/tree/main/shell) | Bridge | released |
| PowerShell | [PowerShell bridge](https://github.com/axisvela/praxo-core/tree/main/powershell) | Bridge | released |
| Visual Basic | [VB.NET sample](https://github.com/axisvela/praxo-core/tree/main/csharp/samples) | Sample | released |

## Wave 2 Candidates

JavaScript, C++, Dart, Ruby, Kotlin, Scala, MATLAB, Perl, Delphi, OCaml/Caml,
Lua, Scratch, COBOL, Prolog, and ABAP are planned in the
[language expansion plan](19-language-expansion.md). JavaScript reuses the
TypeScript package; Kotlin and Scala reuse the Java SDK.
