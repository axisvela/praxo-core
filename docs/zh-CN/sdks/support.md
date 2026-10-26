# SDK 支持政策

Go 是参考实现。[语言支持矩阵](https://github.com/axisvela/praxo-core/blob/main/spec/languages.md)
记录各语言的声明范围、源码标签与 CI 覆盖；该矩阵是实现状态的规范来源。

| 实现类型 | 含义 |
| --- | --- |
| Core | 实现声明的核心契约，通过共享行为向量验证 |
| Wire | 序列化和声明的 wire 契约，不代表拥有原生 Agent 循环 |
| Bridge | 通过进程或 HTTP 边界调用受维护运行时 |
| Sample | 复用其他 SDK 的示例，不是独立契约实现 |

实现类型不是稳定性等级，也不保证拥有 Go 的全部功能。C 虽在矩阵中属于 Core，
当前公开 API 仍是 wire 级别。采用前应阅读具体语言的限制。

## 版本与分发

- 核心、SDK、适配器与契约独立版本化，每个 SDK 声明其 `SPEC_VERSION`。
- 源码标签不等于已发布到包管理器，应按语言页面中的安装或源码构建步骤操作。
- Python、TypeScript 当前提供源码构建方式，PyPI、npm 发布仍待完成。
- Java 提供 Maven 源码构建方式，源码标签不证明 Maven Central 可用。
- Fortran 仍在开发中，不应作为已发布的软件包宣传。

## 功能边界

Python、TypeScript、Java、C# 包含流式路径与 OpenAI 兼容适配器，不能据此推断
其他语言也具备这些能力。共享向量通过不等于 Go 全功能一致、真实提供商验证、
生产就绪或包仓库发布完成。

VFS、插件宿主、调度与可选集成应以对应 SDK 的 README 和 API 参考为准。
贡献要求见 [SDK 设计](../contributing/sdk-design.md)和
[语言支持规范](../contributing/language-policy.md)。
