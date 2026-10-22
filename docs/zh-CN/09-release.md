# 发布流程

## 纪律

- 版本使用干净的 semver：`major.minor.patch`。不使用 `-rc`、`-beta` 或其他
  后缀。
- `PRAXOVELA` 和 `PRAXOVELA-open` 共享完全相同的 `vX.Y.Z` 标签。
  `PRAXOVELA-EE` 可以在相同的干净 semver 方案上独立发布。
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

## 打标签与发布

```bash
git tag -s v1.0.0 -m "praxo-core v1.0.0"
git tag -v v1.0.0
git push origin v1.0.0
```

`release.yml` 工作流验证标签与 `VERSION` 匹配，运行测试门禁，生成 SBOM，
创建源码归档/校验和，并发布 GitHub Release。

## 使用方更新

1. 将 `PRAXOVELA` 模块固定版本更新为 `vX.Y.Z`。
2. 在 `packages/axon-core` 中运行 `go mod tidy` 和 `go mod vendor`。
3. 运行完整的 `PRAXOVELA` 和 `PRAXOVELA-open` 测试套件。
4. 更新 `PRAXOVELA-EE` 中的提取文档。

## 清单

- [ ] `VERSION` 和 `CHANGELOG.md` 已更新
- [ ] API 快照和差异已审查
- [ ] release-check、race、fuzz、staticcheck、govulncheck 通过
- [ ] 安全检查清单完成
- [ ] SBOM 和校验和已生成
- [ ] 签名标签已创建并验证
- [ ] GitHub Release 已发布
- [ ] PRAXOVELA 和 PRAXOVELA-open 已固定版本并测试
