# Containment 评估

本页总结 PRAXO-CORE 公开测试的 containment 属性。它不是渗透测试、合规认证，
也不表示已部署产品自动继承这些属性。威胁模型和信任边界见[安全模型](index.md)。

## 已测试边界

| 边界 | 公开控制 |
| --- | --- |
| 文件系统 path grant | 默认拒绝；空 grant 拒绝；read、write、readwrite 分别检查 |
| Traversal 与 sibling 前缀 | 拒绝 traversal 和 sibling-prefix 逃逸 |
| Symlink | 比较前解析 grant root 和 target |
| 畸形路径 | NUL 字节和 Windows drive-relative 路径失败关闭 |
| Windows 特殊名称 | 本地 VFS 拒绝保留设备名、alternate data stream、尾部点或空格 |
| VFS | 本地 backend 拒绝绝对路径，并通过 `policy.PathChecker` 路由 |
| Plugin 生命周期 | 只有 active plugin 接受调用；终态不可逆 |
| Process host | 平台 supervisor 施加进程树和资源限制 |
| WASM host | 测试 linear-memory 边界和 timeout/cancellation 终止 |
| WASM CPU 边界 | start/invoke deadline 和 context cancellation 会终止 CPU-bound guest；固定 wazero API 不提供 per-instruction fuel metering |
| HTTP | 默认开启 TLS 校验，响应 body 有界 |
| Tool 授权 | 执行前重新授权最终 tool name 和 arguments |

## 开放区域

Containment 是分层且产品自有的。调用方仍须根据威胁模型提供 OS 级隔离、可信
base URL、signature/SBOM 校验、审批绑定和幂等性。

固定的 `wazero` API 不暴露 per-instruction fuel metering。不要声称 WASM host
具备基于 fuel 的 CPU 限制。其已测试 CPU 边界是配置的 start/invoke deadline 加
context cancellation，可终止不配合的 guest；增加 fuel accounting 需要经过
review 的依赖变更和新测试。

自 `2.5.2` 起，本地 VFS 使用 `policy.PathChecker` 授权虚拟路径，然后通过
rooted `os.Root` handle 执行 read、write、stat、listing、delete、glob 和递归
Grep 文件读取。Policy 检查后替换的 symlink 不能把实际文件操作重定向到 workspace
root 外。`os.Root` 拒绝绝对 symlink，因此 workspace symlink 应使用相对 target。
`Grep` 仍在读取前校验每个文件；被拒绝路径会中止且不产生部分匹配。localfs 之外的
policy 决策仍是 check-then-use，高风险调用方仍应增加 OS 级限制。

Symlink 回归测试需要允许创建 symlink 的 host；跳过的测试不算 containment 验证。
Linux CI 运行 symlink case；没有 symlink 权限的 Windows host 会报告 skipped。

独立 containment review 请求记录在[issue #8](https://github.com/axisvela/praxo-core/issues/8)。
