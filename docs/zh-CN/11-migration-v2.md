# PRAXO-CORE v2 迁移

**状态：** v2 分支，2026-10-18。

v2 为语义导入版本控制更改了 Go 模块路径。导出的 API、能力包、JSON 标签和
线格式契约与 1.7.0 保持不变。

## 模块路径

```go
require github.com/axisvela/praxo-core/v2 v2.0.0
```

所有导入从：

```go
"github.com/axisvela/praxo-core/pkg/agent"
```

改为：

```go
"github.com/axisvela/praxo-core/v2/pkg/agent"
```

## 使用方步骤

1. 更新 `go.mod`：

   ```sh
   go get github.com/axisvela/praxo-core/v2@v2.0.0
   ```

2. 重写源文件中的导入：

   ```sh
   rg -l '"github.com/axisvela/praxo-core/' | xargs sed -i \
     's#"github.com/axisvela/praxo-core/#"github.com/axisvela/praxo-core/v2/#g'
   ```

   在 PowerShell 上：

   ```powershell
   Get-ChildItem -Recurse -Filter *.go | ForEach-Object {
     $c = [System.IO.File]::ReadAllText($_.FullName)
     $n = $c.Replace('"github.com/axisvela/praxo-core/', '"github.com/axisvela/praxo-core/v2/')
     if ($n -ne $c) {
       [System.IO.File]::WriteAllText($_.FullName, $n, (New-Object System.Text.UTF8Encoding($false)))
     }
   }
   ```

3. 移除任何 v1 `replace` 指令，或将其指向 v2 检出目录。
4. 运行 `go mod tidy`、`go test ./...` 和 `go build ./...`。

## 兼容性

- 根 `agent.*` 别名保留，因此除非需要，能力类型无需从子包导入。
- 尚未迁移的使用方仍可使用 v1 标签。
- v2 不会移除 `toolcall.ToolCall` 治理元数据；它仍是 PRAXOVELA 使用的产品
  契约。

## 发布门禁

在 PRAXOVELA/open 和 EE 拥有通过完整测试套件的 v2 分支之前，不要发布
`v2.0.0`。
