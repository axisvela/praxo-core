# 将 Core 嵌入 HTTP 服务

本教程使用可运行的
[`examples/embedded-service`](https://github.com/axisvela/praxo-core/tree/main/examples/embedded-service)
项目，展示厂商中立服务的最小形态：调用方上下文通过 HTTP 进入，应用选择租户，
Core 执行 Agent，服务返回结构化输出。

## 运行

```bash
export PRAXO_BASE_URL=http://localhost:11434/v1
export PRAXO_MODEL=llama3.2

cd examples/embedded-service
go run . -addr :8080 -tenant local
```

调用服务：

```bash
curl -s http://localhost:8080/run \
  -H 'Content-Type: application/json' \
  -H 'X-Praxo-Principal: user-1' \
  -d '{"prompt":"What time is it? Use get_time."}'
```

## Python 变体

Python 示例使用相同的调用方上下文边界和标准库 HTTP Server：

```bash
cd language/python/examples/service
python -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
.venv/bin/python service.py
```

```bash
curl -s http://127.0.0.1:8080/run \
  -H 'Content-Type: application/json' \
  -H 'X-Praxo-Principal: user-1' \
  -d '{"prompt":"What time is it? Use get_time."}'
```

确定性测试：

```bash
.venv/bin/python -m unittest test_service.py -v
```

## 已验证身份变体

[认证服务示例](https://github.com/axisvela/praxo-core/tree/main/examples/embedded-service-auth)
增加应用侧 HMAC Bearer Token、subject/tenant claims、过期检查、Agent 运行前的
租户允许列表，以及运行完成时保存的文件型 Checkpoint。设置 `PRAXO_OIDC_ISSUER` 后改为
验证 OIDC/JWKS JWT，并可从 Issuer 元数据发现 `jwks_uri`。设置
`PRAXO_INTROSPECTION_URL` 后改用 RFC 7662 introspection；`--revoke-token TOKEN`
通过 RFC 7009 撤销。两者同时配置时 introspection 优先。

```bash
cd examples/embedded-service-auth
go test ./...
```

默认使用应用局部 Token 格式，不是通用 JWT 实现。生产服务应使用自己的身份提供商、
密钥管理、audience 校验和撤销机制。

## Python 认证变体

[Python 认证服务示例](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/service-auth)
使用标准库实现同样的边界：HMAC Bearer Token、subject/tenant claims、过期检查、
租户允许列表、策略绑定，以及文件型 Checkpoint。设置 `PRAXO_POLICY_URL` 可把决策
委托给应用拥有的 HTTP 策略决策服务；超时、响应无效或拒绝都会 fail closed。设置
`PRAXO_OIDC_ISSUER` 后改为验证 OIDC/JWKS JWT，并可从 Issuer 元数据发现 `jwks_uri`。
设置 `PRAXO_INTROSPECTION_URL` 后改为通过 RFC 7662 校验不透明 Token；
`service.py --revoke-token TOKEN` 可通过 `PRAXO_REVOCATION_URL` 或 Issuer discovery
发现的 RFC 7009 端点撤销 Token。

```bash
cd language/python/examples/service-auth
python -m venv .venv
.venv/bin/python -m pip install -r requirements.txt

export PRAXO_SERVICE_SECRET=local-development-secret
.venv/bin/python service.py --addr 127.0.0.1:8080
```

生成短期 Token 并调用服务：

```bash
TOKEN=$(.venv/bin/python service.py --print-token user-1 local --ttl 600)
curl -s http://127.0.0.1:8080/run \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"prompt":"What time is it? Use get_time."}'
```

运行确定性测试：

```bash
.venv/bin/python -m unittest test_service.py -v
```

## TypeScript 认证变体

[TypeScript 认证服务示例](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples/service-auth)
使用 Node 标准库实现同样的 HMAC Bearer Token、租户允许列表、策略绑定、可选外部
策略决策服务，以及文件型 Checkpoint。设置 `PRAXO_OIDC_ISSUER` 后，它会验证外部
身份提供商的 OIDC/JWKS JWT，并可从 `.well-known/openid-configuration` 发现
`jwks_uri`。设置 `PRAXO_INTROSPECTION_URL` 后改为通过 RFC 7662 端点校验不透明
Token。示例还提供 `node service.js --revoke-token TOKEN`，通过 RFC 7009 端点撤销
Token；Provider 端点不可用时失败关闭。

```bash
cd language/typescript/examples/service-auth
npm ci

export PRAXO_SERVICE_SECRET=local-development-secret
npm start
```

生成 Token 并调用服务：

```bash
TOKEN=$(node service.js --print-token user-1 local --ttl 600)
curl -s http://127.0.0.1:8080/run \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"prompt":"What time is it? Use get_time."}'
```

运行确定性测试：

```bash
npm test
```

## Java 与 C# 认证变体

Java 和 C# 服务示例也支持 RFC 7662 introspection 与 RFC 7009 撤销：

- 设置 `PRAXO_INTROSPECTION_URL`、`PRAXO_INTROSPECTION_CLIENT_ID` 和
  `PRAXO_INTROSPECTION_CLIENT_SECRET` 后验证 `Authorization: Bearer` 不透明 Token；
- 设置 `PRAXO_REVOCATION_URL` 后使用 `--revoke-token TOKEN` 撤销；
- 租户从 `PRAXO_OIDC_TENANT_CLAIM`（默认 `tenant`）读取；
- C# 示例在设置 `PRAXO_OIDC_ISSUER` 与 `PRAXO_OIDC_AUDIENCE` 后还验证带 Provider
  发现的 OIDC/JWKS JWT；
- Java 示例包含 OIDC/JWKS 验证并在 Linux CI 通过；本机 Windows JVM 启动器仍挂起。

C# OIDC 测试使用 loopback discovery/JWKS Provider；introspection 与撤销测试使用
loopback 或 fake 端点。不需要外部身份提供商。

## 传输中立与可注入认证变体

Ruby、PHP、Dart、Elixir、Erlang 和 Perl 服务示例仍是请求处理器，不是可执行
HTTP 服务。它们提供可注入 transport 的 introspection 与撤销模块：

- Ruby：`language/ruby/examples/service/authentication.rb` 和
  `NetHttpTransport`；
- PHP：`language/php/examples/service/authentication.php` 和
  `StreamTransport`；
- Dart：`language/dart/examples/service/authentication.dart` 和
  `HttpTransport`；
- Elixir：`language/elixir/examples/service/authentication.ex` 和
  `HttpTransport`；
- Erlang：`language/erlang/examples/service/authentication.erl` 和调用方提供的
  transport；
- Perl：`language/perl/examples/service/ServiceAuth.pm` 和 `HTTP::Tiny`
  transport。

相同的 introspection/撤销契约已在 Rust、Lua、D、C、C++、Objective-C、
Delphi/Free Pascal、Zig、Fortran 和 PowerShell 本地验证；模块路径与确定性测试命令见各自的
`examples/service/README.md`。

应用必须在 Handler 之前完成认证，并从验证结果派生 principal/tenant。不包含 OIDC/JWKS。
前六种语言的确定性测试命令为：

```bash
elixir language/elixir/examples/service/authentication_test.exs
mkdir -p build
erlc -o build language/erlang/examples/service/authentication.erl language/erlang/examples/service/authentication_test.erl
erl -noshell -pa build -s authentication_test main -s init stop
perl language/perl/examples/service/authentication_test.pl
```

Java、C# 和 Swift 保留标准客户端 transport；Java 与 C# 使用 loopback 测试，Swift
目前只能本地类型检查。Haskell、OCaml、Julia、Nim、V、R 和 MATLAB/Octave 已有源码，
但因工具链缺失未验证。COBOL 仅记录 transport 边界。

## 其他语言示例

每种已声明 Core 都提供 `language/<language>/examples/service` 示例。下表列出在仓库根目录运行的
确定性命令。Go、Python、TypeScript、Java、C# 和 Rust 包含可执行的 HTTP 服务；其余包含
传输中立的请求处理机制，深度不一，部分不调用 Core、工具或租户策略，不能视为等价的
嵌入服务或认证实现。[语言覆盖页](../getting-started/language-coverage.md)记录示例模式。

| 语言 | 运行命令 |
| --- | --- |
| Go | `cd examples/embedded-service && go run . -addr :8080 -tenant local` |
| Python | `cd language/python/examples/service && .venv/bin/python service.py` |
| TypeScript | `cd language/typescript/examples/service && npm start` |
| Java | `cd language/java/examples/service && mvn -q compile exec:java` |
| C# | `cd language/csharp/examples/service && dotnet run` |
| Rust | `cd language/rust/examples/service && cargo run` |
| C | `gcc -std=c11 language/c/examples/service/main.c -o build/c-service && ./build/c-service` |
| C++ | `g++ -std=c++20 language/cpp/examples/service/main.cpp -o build/cpp-service && ./build/cpp-service` |
| COBOL | `python language/cobol/examples/service/build.py` |
| D | `dmd -run language/d/examples/service/service.d` |
| Dart | `dart language/dart/examples/service/service.dart` |
| Delphi / Free Pascal | `fpc -Mobjfpc language/delphi/examples/service/service.pas && ./service` |
| Elixir | `elixir language/elixir/examples/service/service.exs` |
| Erlang | `escript language/erlang/examples/service/service.escript` |
| Fortran | `gfortran language/fortran/examples/service/service_example.f90 -o build/fortran-service && ./build/fortran-service` |
| Haskell | `runghc language/haskell/examples/service/service.hs` |
| Julia | `julia language/julia/examples/service/service.jl` |
| Lua | `lua language/lua/examples/service/service.lua` |
| MATLAB / Octave | `octave-cli --path language/matlab/examples/service --eval service_example` |
| Nim | `nim r language/nim/examples/service/service.nim` |
| Objective-C | `clang -fobjc-arc language/objc/examples/service/service.m -framework Foundation -o build/objc-service && ./build/objc-service` |
| OCaml | `ocaml language/ocaml/examples/service/service.ml` |
| Perl | `perl language/perl/examples/service/service.pl` |
| PHP | `php language/php/examples/service/service.php` |
| PowerShell | `powershell -File language/powershell/examples/service/service.ps1` |
| R | `Rscript language/r/examples/service/service.R` |
| Ruby | `ruby -I language/ruby/lib language/ruby/examples/service/service.rb` |
| Swift | `swift run --package-path language/swift praxo-service-example` |
| V | `v run language/v/examples/service/service.v` |
| Zig | `zig run language/zig/examples/service/service.zig` |

源码模式 Handler 示例的 `service example passed` 只说明本地断言通过。状态码检查不能证明
零工具效果，后者需要经过 Core 并统计工具调用。它们不证明身份验证、持久状态或生产 HTTP 行为。

## 请求流程

1. 基础 HTTP Handler 检查 `X-Praxo-Principal` 是否存在；认证变体验证 Bearer Token
   并推导 principal。
2. 应用选择租户，并将 principal 和 tenant 传入 Core Session。
3. Agent 在显式超时下调用模型。
4. Policy 只允许模型生成和 `get_time` 工具。
5. Handler 返回包含模型输出的 JSON。

`X-Praxo-Principal` 只是上下文占位，不是认证。生产服务必须验证调用方，并从可信
应用状态中推导 principal 和 tenant。

## 服务边界

基础示例包含：

- `/healthz` 健康检查；
- 有大小限制的 `POST /run` JSON 请求；
- HTTP 读、写和空闲超时；
- 模型 HTTP 超时；
- SIGINT/SIGTERM 有界优雅退出；
- 由应用拥有的事件日志。

基础示例有意不包含持久 Session、Checkpoint、审批或租户存储。这些属于应用或产品职责。
认证变体增加了有界 Token 校验和文件型 Checkpoint。

## 无需模型的测试

```bash
cd examples/embedded-service
go test ./...
```

测试使用 fake model 和 `httptest`，不需要真实端点。

## 下一步

- 用已认证身份替换 principal Header。
- 按租户隔离 Checkpoint、事件和工具访问。
- 为长时工作增加持久 Checkpoint 存储。
- 将 Shell、文件和网络工具置于应用拥有的隔离之后。
- 上线前使用[应用嵌入清单](application-integration-checklist.md)。

## 相关文档

- [应用嵌入清单](application-integration-checklist.md)
- [身份与策略](identity-policy.md)
- [长时操作](long-running-operations.md)
- [安全模型](../security/index.md)
- [示例目录](../getting-started/examples.md)
