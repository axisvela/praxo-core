# 公开路线图

当前核心版本为 `2.5.0`。本文说明技术方向，不承诺交付排期，也不表示所有 SDK
都具有每一项功能。

## 当前方向

- 加强文件系统竞态、进程树和 WASM 资源耗尽场景的隔离测试。
- 改进可运行的可观察性示例与事件、OpenTelemetry 指南。
- 在推广可选工作区契约前完成真实提供商验证。
- 支持独立实现运行共享一致性测试。
- 改善各语言的安装、分发和兼容性证据。

## 兼容承诺

保持 Go 公开 API 精简、MIT 边界完整，新契约需要消费者和测试。不能仅为移植 SDK
扩大 Go API。参见[兼容政策](compatibility-policy.md)、[SDK 支持](../sdks/support.md)
与[语言规范](../contributing/language-policy.md)。

## 已交付内容

参见[版本历史](../releases/index.md)和
[完整变更日志](https://github.com/axisvela/praxo-core/blob/main/CHANGELOG.md)。
可选适配器的离线评估不等于真实生产验证。
