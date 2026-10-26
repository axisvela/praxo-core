# 发布流程

## 纪律

- 版本使用干净的 semver：`major.minor.patch`。不使用 `-rc`、`-beta` 或其他
  后缀。
- 产品仓库可以在相同的干净 semver 方案上独立发布。
- 在打标签之前更新 `VERSION` 和 `CHANGELOG.md`。
- 发布标签由操作员签名。如果没有可用的签名密钥，使用附注标签并在发布说明
  中记录该事实；优先使用签名标签。

## 发布前门禁

在受支持的平台上从仓库根目录运行：

```powershell
.\scripts\release-check.ps1 -Fuzz
```

在 Linux 上运行竞态作业（Windows 竞态检测器需要可用的 cgo 工具链）：

```bash
GOWORK=off go test -race ./...
```

发布还需要：

- Linux、Windows 和 macOS 的 CI 通过
- race/fuzz/staticcheck/govulncheck 作业通过
- API 差异审查（见下文）
- 按 `docs/08-security.md` 完成安全审查
- 生成 SBOM 和校验和

## API 差异

为上一个版本和候选版本生成快照：

```powershell
.\scripts\api-snapshot.ps1 -Version 0.16.0
.\scripts\api-snapshot.ps1 -Version 1.0.0
.\scripts\api-diff.ps1 -From 0.16.0 -To 1.0.0
```

将候选快照提交到 `api/<version>.txt`。每个新增、删除或更改的导出声明都必须
是有意的，并反映在 `CHANGELOG.md` 和 `docs/05-compatibility.md` 中。

## SBOM

```powershell
go install github.com/CycloneDX/cyclonedx-gomod/cmd/cyclonedx-gomod@latest
.\scripts\sbom.ps1
```

结果是 `dist/sbom.json`。发布工作流在 Linux 上运行相同命令。

## 源码归档与校验和

```powershell
.\scripts\checksums.ps1 -Version 1.0.0
```

这会写入 `dist/praxo-core-1.0.0.tar.gz` 和 `dist/SHA256SUMS`。

## 可选适配器模块

`adapters/<name>` 下的模块有自己的 `go.mod` 和独立语义化版本线。它们让提供商
和协议 SDK 不进入核心模块，因此核心发布不要求适配器发布，反之亦然。

可选模块使用 `adapters/<name>/vX.Y.Z` 标签：

```bash
git tag -s adapters/mcp/v0.3.1 -m "praxo-core adapters/mcp v0.3.1"
git tag -v adapters/mcp/v0.3.1
git push origin adapters/mcp/v0.3.1
```

已存在的模块标签不可移动。使用方通过标签中的版本段安装模块：

```bash
go get github.com/axisvela/praxo-core/adapters/mcp@v0.3.1
```

模块标签必须与模块的 `go.mod` 路径匹配。打标签前，在同一次变更中更新模块
`README.md` 和 `docs/adapters.md`，并在模块目录运行 test、vet 和 build。根目录的
`release.yml` 只响应 `v*` 标签；`adapters/mcp/v0.3.1` 这类标签不会生成核心归档、
SBOM 或 GitHub Release。可选模块发布需单独验证和发布。

当前可选模块：

- [`adapters/mcp`](https://github.com/axisvela/praxo-core/tree/main/adapters/mcp) - MCP 工具、资源和提示词
- [`adapters/otel`](https://github.com/axisvela/praxo-core/tree/main/adapters/otel) - OpenTelemetry 事件接收器
- [`adapters/anthropic`](https://github.com/axisvela/praxo-core/tree/main/adapters/anthropic) - 原生 Anthropic 适配器
- [`adapters/gemini`](https://github.com/axisvela/praxo-core/tree/main/adapters/gemini) - 原生 Gemini 适配器

同一方案适用于 `adapters/harmovela`、`adapters/a2a` 和 `adapters/multiagent`。
OpenAI 兼容适配器只使用标准库，因此保留在核心模块中。

## 标签身份

- 发布标签使用发布签名身份：`AxisVela Release Signing <releases@axisvela.com>`。
- 已有标签保留其记录的身份；新标签不得使用个人身份。
- 仅为打标签命令临时设置 committer 身份，不要永久修改仓库配置；用 `-u`
  显式选择发布密钥：

```powershell
$env:GIT_COMMITTER_NAME="AxisVela Release Signing"
$env:GIT_COMMITTER_EMAIL="releases@axisvela.com"
git tag -s -u <release-key-id> v2.5.1 -m "praxo-core v2.5.1"
```

## 多语言标签

- `spec/vX.Y.Z` 标记规范契约，必须与 `spec/SPEC_VERSION` 一致。
- `python/vX.Y.Z` 标记 Python SDK，必须与 `python/pyproject.toml` 一致。
- `python/adapters/<name>/vX.Y.Z`、`typescript/...` 和 `java/...` 采用相同的
  按语言划分方案。
- 这些标签不触发 `release.yml`（仅 `v*`），不生成 Go 归档、SBOM 或 GitHub
  Release。
- 仅在一致性向量和一致性 linter 通过后才打 spec 或 SDK 标签。

## 打标签与发布

```bash
git tag -s v1.0.0 -m "praxo-core v1.0.0"
git tag -v v1.0.0
git push origin v1.0.0
```

`release.yml` 工作流验证标签与 `VERSION` 匹配，运行测试门禁，生成 SBOM，
创建源码归档/校验和，并发布 GitHub Release。

## 使用方更新

1. 将下游模块固定版本更新为 `vX.Y.Z`。
2. 在每个使用方模块中运行 `go mod tidy` 和 `go mod vendor`。
3. 运行所有下游测试套件。
4. 在内部发布跟踪记录中登记发布证据。

## 清单

- [ ] `VERSION` 和 `CHANGELOG.md` 已更新
- [ ] API 快照和差异已审查
- [ ] 隐私检查通过：无内部邮箱域名和 `.internal` 主机名
- [ ] release-check、race、fuzz、staticcheck、govulncheck 通过
- [ ] 安全检查清单完成
- [ ] SBOM 和校验和已生成
- [ ] 签名标签已创建并验证
- [ ] GitHub Release 已发布
- [ ] 下游使用方已固定版本并测试
