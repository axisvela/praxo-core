# Visual Basic Sample

Visual Basic 使用 C# / .NET Core 程序集。它是一个示例，不是独立的 agent 循环
或契约实现。

在仓库根目录使用 .NET Core 运行：

```bash
dotnet run --project language/csharp/samples/VbSample
```

运行时要求、支持能力、契约版本和限制见 [C# / .NET Core](../csharp/index.md)，
用法见 [VB 示例源码](https://github.com/axisvela/praxo-core/tree/main/language/csharp/samples/VbSample)。
不暗示存在独立的 Visual Basic 包或发布。

## 代表性链路与治理

Visual Basic 直接使用 C# Core。请运行宿主语言示例，而不是创建单独的
Visual Basic 链路：

- [C# 代表性链路测试](https://github.com/axisvela/praxo-core/blob/main/language/csharp/Praxo.Tests/RepresentativeChainTests.cs)
- [C# 高级委派](https://github.com/axisvela/praxo-core/tree/main/language/csharp/examples/advanced-delegation)
