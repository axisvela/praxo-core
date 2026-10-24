# 插件信任与 SBOM 交接

**状态：** 公开交接清单。本文说明产品在启动插件宿主前必须验证什么。它不是
签名验证器、SBOM 存储或安全认证。

## 边界

PRAXO-CORE 宿主只启动已经验证过的载荷。产品负责获取、签名验证、SBOM 策略、
信任根、materialization 和更新策略。

| 职责 | PRAXO-CORE | 产品 |
| --- | --- | --- |
| 严格解析和 v1 manifest 校验 | 是 | 必须调用 |
| signed profile 存在性检查 | 是 | 必须执行 |
| 加密签名验证 | 否 | 是 |
| 信任根、密钥轮换、吊销 | 否 | 是 |
| 制品下载与摘要校验 | 否 | 是 |
| SBOM 获取、匹配与策略 | 否 | 是 |
| 内容寻址 materialization | 否 | 是 |
| 进程/WASM 运行时限制 | 是 | 必须要求 |
| 容器隔离 | 否 | 是 |
| 生命周期与 ACTIVE 门禁 | 是 | 必须使用 |
| 持久证据与审计 | 否 | 是 |

## 制品集合

一次已签名插件发布应包含：

1. **Manifest v1**：严格 JSON，包含 `schemaVersion`、`id`、`version`、`kind`、
   `entrypoint`、`protocol`、`capabilities`、`permissions`、`limits`、
   `isolation`、`health`、`signature` 和 `sbom`。
2. **分离签名**：对规范描述符字节的签名。Manifest 只携带算法和 `keyId`，
   不携带签名值。
3. **SBOM**：SPDX 或 CycloneDX，描述制品及其依赖。
4. **制品字节**：进程二进制、WASM 模块或容器镜像。
5. **来源/证明**（可用时）：构建身份、源码版本和签名者。

Manifest 的 `signature` 字段是身份声明。`ValidateTrust` 只检查签名身份和
SBOM 路径是否存在，不验证加密有效性。

## 产品必须执行的流程

1. 通过 TLS 或固定通道从可信来源获取描述符和制品。
2. 用 `plugin.ParseManifest` 解析。它会拒绝未知字段和尾随数据。
3. 用 `ValidateTrust(plugin.TrustSigned)` 执行信任配置。未签名制品只能通过
   显式本地开发配置允许。
4. 验证对规范描述符字节的分离签名。
   - 允许列表限制算法。
   - 在产品信任库中解析 `keyId`。
   - 检查密钥状态、轮换和吊销。
   - 拒绝未知或过期密钥。
5. 验证制品摘要与已签名描述符和 SBOM 一致。
6. 验证 SBOM 与制品摘要匹配，并满足产品的许可证、漏洞和来源策略。
7. 检查兼容性：`schemaVersion`、契约 `kind`、protocol、isolation、核心版本和
   平台。
8. 将权限绑定到租户和工作区。Manifest 默认拒绝；不要添加额外环境变量或扩大
   文件系统/网络授权。
9. 将制品 materialize 到内容寻址、只读路径。拒绝符号链接、路径穿越和意外写入。
10. 用已验证制品和 provider 身份构造核心宿主，并在生产环境设置
    `RequireEvidence` 和 `RequireLimits`。
11. 启动宿主；对新宿主实现运行
    [契约 TCK](10-plugin-authoring.md)，并执行生命周期。
12. 在运行前后记录持久证据。

## 失败语义

- 缺少、无效或已吊销签名：不启动宿主。
- 缺少或不匹配 SBOM：不启动宿主。
- 制品摘要不匹配：隔离制品，不启动宿主。
- schema、kind、protocol、isolation 或平台不兼容：拒绝。
- signed profile 下的未签名制品：拒绝，不得静默降级。
- 启动后发生吊销：按产品策略停止或隔离，并记录决策。
- 验证服务不可用视为失败，不得回退到未签名。

## SBOM 要求

- 使用 SPDX 2.3+ 或 CycloneDX 1.5+。
- 包含制品摘要和所有捆绑依赖。
- 包含许可证标识；需要时包含来源信息。
- 策略要求时，对 SBOM 签名或将其纳入发布证明。
- 将 SBOM 及其摘要与部署证据一起保存。
- 拒绝覆盖不同制品摘要的 SBOM。

## 需要持久化的证据

产品至少应记录：

- 描述符哈希和规范化版本
- manifest ID、version、kind 和 schemaVersion
- 签名算法、`keyId`、验证结果和信任根版本
- 制品摘要和 materialized 路径
- SBOM 摘要和策略结果
- 兼容性决策和授予的权限
- 宿主生命周期事件、资源限制事件和终止原因
- 租户、工作区、操作者和审批引用

设置 `RequireEvidence` 后，核心宿主通过配置的 sink 发出生命周期和资源限制
证据。它不创建持久审计日志。

## 交接清单

- [ ] 描述符和制品来自可信来源
- [ ] `ParseManifest` 和 `Validate` 通过
- [ ] 执行 signed profile；未签名仅用于显式本地开发
- [ ] 分离签名已验证；算法和 `keyId` 在允许列表中
- [ ] 信任根、轮换和吊销已检查
- [ ] 制品摘要与已签名描述符和 SBOM 一致
- [ ] SBOM 策略通过；SBOM 摘要已记录
- [ ] schema、kind、protocol、isolation、核心版本和平台兼容
- [ ] 权限绑定到租户/工作区；无环境变量泄漏
- [ ] 制品以只读、内容寻址路径 materialize
- [ ] 宿主使用已验证身份和证据/资源要求构造
- [ ] 新宿主实现通过 TCK
- [ ] 运行前后记录持久证据

## 核心限制

- `pkg/plugin` 不获取制品、不解析依赖，也不调用信任库。
- `ValidateTrust` 检查存在性，不检查加密有效性。
- 核心提供进程和 WASM 宿主。容器隔离和容器镜像验证由产品负责。
- 进程宿主应用 `Limits.ResourceLimits`。WASM 宿主使用 `MaxMemoryPages` 和
  `MaxConcurrency`，因此产品必须把 manifest 限制映射到宿主配置。
- 核心不执行完整网络权限模型。产品必须执行出站策略。
- 进程宿主 token 通过环境变量传递，不通过 argv。产品仍负责密钥存储和轮换。
- 插件宿主启动成功不等于信任、SBOM 合规或生产隔离得到证明。

## 示例

```go
manifest, err := plugin.ParseManifest(raw)
if err != nil {
    return err
}
if err := manifest.ValidateTrust(plugin.TrustSigned); err != nil {
    return err
}
if err := verifier.Verify(ctx, raw, manifest.Signature); err != nil {
    return err
}
if err := sbom.Verify(manifest.SBOM, artifactDigest); err != nil {
    return err
}
path, err := materializer.Put(ctx, artifact)
if err != nil {
    return err
}
host, err := process.New(process.Config{
    PluginID:        manifest.ID,
    Provider:        provider,
    Path:            path,
    Sink:            evidenceSink,
    RequireEvidence: true,
    RequireLimits:   true,
    Limits:          manifest.Limits.ResourceLimits(),
})
if err != nil {
    return err
}
if err := host.Start(ctx); err != nil {
    return err
}
defer host.Stop(ctx)
```

verifier、SBOM 策略、信任库、materializer 和 evidence sink 都是产品组件。示例
只展示交接点。

## 非目标

- 框架内置信任库、签名服务或 SBOM 数据库。
- 核心内实现容器镜像 materialization 或隔离。
- 插件网络出站强制执行。
- 声称未签名本地开发配置可用于生产。
