# Core 与 Adapter 布局

执行内核与可选集成保持分离。Core 不得导入 provider SDK、仅供 adapter 使用的 HTTP
客户端或产品包。Adapter 是可选的，可独立变化，不得扩大 Go API。

## Go

- Core：`pkg/...`
- 可选 adapter：`adapters/<name>/`，独立模块
- 共享规范：`spec/`

## 独立 Core 实现

在语言包内使用 `adapters/` 子目录。若移动会破坏消费者，保持公共 module/package
名称稳定；在旧路径保留 re-export 或薄兼容文件。

| 语言 | Adapter 位置 | 状态 |
| --- | --- | --- |
| Python | `praxo/adapters/` | 已分离 |
| TypeScript | `src/adapters/` | 已分离 |
| Java | `src/main/java/com/axisvela/praxo/adapters/` | 已分离 |
| Ruby | `lib/praxo/adapters/` | 已分离 |
| PHP | `src/Adapters/` | 已分离 |
| Perl | `lib/Praxo/Adapters/` | 已分离 |
| Nim | `src/praxo/adapters/` | 已分离 |
| Dart | `lib/src/adapters/` | 已分离 |
| C# | `Praxo.Core/Adapters/` | 已分离（命名空间不变） |
| Swift | `Sources/PraxoCore/Adapters/` | 已分离（模块不变） |
| Julia | `src/adapters/` | 已分离 |
| Lua | `praxo/adapters/` | 计划；旧路径保留 wrapper |
| Haskell | `src/Praxo/Adapters/` | 计划；保留 module re-export |
| Rust | `src/adapters/` | 计划；保留根级 re-export |
| Elixir | `lib/praxo/adapters/` | 计划；module 名称不变 |
| Erlang | `src/adapters/` | 计划；更新构建/app module 列表 |
| OCaml | 独立 adapter module | 计划 |
| C / C++ / Fortran | `adapters/<language>/` | 计划；更新构建 include |
| Delphi / Objective-C / MATLAB / Octave / Zig / V / D | `adapters/` | 计划；更新构建/测试 |
| PowerShell | C# runtime | 继承；无独立 adapter 代码 |

## 规则

1. 没有 adapter 文件时，Core 仍必须编译并通过 conformance。
2. Adapter 文件可选，Core 入口不得导入它们。
3. Adapter 测试可使用注入 transport；不要求真实 provider。
4. 移动时保持公共路径稳定；添加 re-export 或兼容文件。
5. Adapter 移入嵌套目录时更新 API snapshot 扫描器。
6. 同一变更更新语言 README、`REGISTRY.md` 与测试。
7. 不添加改变 MIT 许可边界的依赖。
