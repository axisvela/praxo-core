# 仓库布局与源码迁移

语言源码按职责归类。Go 模块与 `pkg/...` 导入路径、各语言包名、规范 wire 契约、
既有发布标签均保持不变。本次是源码树调整，不是一次新的框架发布。

| 位置 | 职责 |
| --- | --- |
| `pkg/`、`internal/`、`cmd/` | Go 参考实现与桥接 CLI |
| `sdk/<language>/` | 独立语言实现 |
| `bindings/shell/`、`bindings/powershell/` | 运行时桥接 |
| `examples/javascript/`、`examples/kotlin/`、`examples/scala/` | 复用 TypeScript 或 Java 的示例 |
| `adapters/` | 可选集成 |
| `spec/` | 规范契约、共享向量与 parity 清单 |

## 使用方需要更新的路径

原根目录的 Python、TypeScript、Java、Rust、C、C++、C#、PHP、Ruby、Perl、Lua、
Dart、Swift、Julia、R、D、Zig、COBOL 和 Fortran 实现统一迁入 `sdk/`。
Shell 与 PowerShell 迁入 `bindings/`；JavaScript、Kotlin、Scala 迁入 `examples/`。
Visual Basic 示例继续位于 .NET SDK 的 `sdk/csharp/samples/VbSample/`。

更新本地脚本、CI 工作目录、源码依赖、编辑器配置中的路径。仓库根目录示例：

```bash
pip install ./sdk/python
cmake -S sdk/c -B build/c
swift build --package-path sdk/swift
```

Swift 与 C 的源码消费者需要明确选择新目录。普通 Swift Git 包依赖不能仅通过 URL
选择嵌套 manifest，应使用本地包路径或合适的分发包装。本次不新增根 Swift 包。

旧标签保留历史布局，新 checkout 使用新路径，不提供旧根目录的兼容占位。
CMake 应使用全新构建目录，不要复用绑定旧源码位置的缓存。

包名、代码导入和既有标签前缀不随目录变更。源码标签仍不等于已发布到包管理器。
请在新位置执行语言 README 中的一致性、API 与测试命令，功能限制见
[SDK 支持政策](../languages/support.md)。
