# 绑定已验证身份与策略

本配方展示应用层如何使用已验证 principal 进行 Core 授权。Core 提供授权 Hook 与最终操作
复查；应用必须认证调用方、绑定租户与资源，并 fail closed。

它不是身份提供商、策略决策服务、持久审批库或 exactly-once 效果机制。

## 模式

1. **在 Core 之外认证。** 通过身份系统验证调用方，生成包含 actor ID、租户、角色和
   过期时间的 principal。
2. **上下文中只放已验证数据。** 绝不从模型输出或工具参数读取 actor ID/角色。
3. **在 Hook 中授权。** 拒绝缺失、过期或畸形 principal；检查角色、租户、资源、工具名
   与参数。
4. **复查最终操作。** Middleware 或审批编辑可能改变工具名/参数；Core 会对最终值再次授权。
5. **Fail closed。** 必需身份或策略基础设施不可用时返回错误，不得放行执行。

## 受测示例

可运行示例是独立的 L4 配方模块
[`language/go/examples/recipes/identity-go`](https://github.com/axisvela/praxo-core/tree/main/language/go/examples/recipes/identity-go)。
在该目录运行：

```sh
GOWORK=off go test -mod=readonly -run Identity -v ./...
```

| 检查 | 预期结果 |
| --- | --- |
| 缺少已验证 principal | 拒绝；工具零副作用 |
| principal 已过期 | 拒绝；工具零副作用 |
| 租户不匹配 | 拒绝；工具零副作用 |
| 模型声称 admin 角色 | 忽略；拒绝；工具零副作用 |
| 匹配租户的有效 operator | 允许一次 |

配方在认证后把 principal 放入 context value。真实服务中，该值必须来自已验证请求上下文或
身份中间件，而不是 prompt 或模型。

Go 认证服务示例
[`language/go/examples/embedded-service-auth`](https://github.com/axisvela/praxo-core/tree/main/language/go/examples/embedded-service-auth)
展示了服务边界上的同类绑定。它默认验证应用局部 HMAC Token，设置
`PRAXO_OIDC_ISSUER` 后可验证带 Provider 发现的 OIDC/JWKS JWT，设置
`PRAXO_INTROSPECTION_URL` 后可通过 RFC 7662 校验不透明 Token；同时支持 RFC 7009
撤销。

Python 认证 HTTP 服务
[`language/python/examples/service-auth`](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/service-auth)
展示了服务边界上的同类绑定。它验证应用局部 HMAC Bearer Token、OIDC/JWKS JWT，或通过
RFC 7662 introspection 校验不透明 Token；把 subject 和 tenant 绑定到 Session，拒绝过期
或不在允许列表中的租户，只授权 `get_time`，并在运行完成后保存 Checkpoint。它还支持
RFC 7009 撤销，并可将决策委托给应用拥有的 HTTP 策略决策服务，在该服务不可用时
fail closed。运行确定性测试：

```bash
cd language/python/examples/service-auth
python -m unittest test_service.py -v
```

TypeScript 服务示例
[`language/typescript/examples/service-auth`](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples/service-auth)
使用 Node 标准库实现同样的 HMAC 身份、租户允许列表、可选外部策略决策服务和
Checkpoint 模式，还可以验证外部身份提供商的 OIDC/JWKS JWT、发现 Provider 元数据、
校验不透明 Token，并通过应用自有的 Provider 端点撤销 Token。

C# 服务示例
[`language/csharp/examples/service`](https://github.com/axisvela/praxo-core/tree/main/language/csharp/examples/service)
在 HTTP 边界增加 OIDC/JWKS 验证、Provider 发现、introspection 与撤销。其确定性测试使用
loopback discovery/JWKS Provider，覆盖允许、错误 audience、过期、错误 issuer、未知 key 与
Provider 不可用。

## 全语言示例

每种已声明 Core 都提供 `language/<language>/examples/identity-policy` 示例，但深度不同：
部分只检查应用授权谓词，不运行 Core 或工具。只有经过 Core 并统计工具效果的集成，
才能证明拒绝零效果，不能由独立谓词检查推断。以下命令在仓库根目录运行。

| 语言 | 运行命令 |
| --- | --- |
| Go | `cd language/go/examples/recipes/identity-go && GOWORK=off go test -mod=readonly -run Identity -v ./...` |
| Python | `cd language/python/examples/identity-policy && .venv/bin/python -m unittest test_identity_policy.py -v` |
| TypeScript | `cd language/typescript/examples/identity-policy && npm test` |
| Java | `cd language/java/examples/identity-policy && mvn -q compile exec:java` |
| C# | `cd language/csharp/examples/identity-policy && dotnet run -- --test` |
| Rust | `cd language/rust/examples/identity-policy && cargo run` |
| C | `gcc -std=c11 -I language/c/include language/c/examples/identity-policy/main.c language/c/build/libpraxo_core.a -o build/c-identity-policy && ./build/c-identity-policy` |
| C++ | `g++ -std=c++20 -I language/cpp/include language/cpp/examples/identity-policy/main.cpp language/cpp/build/libpraxo_cpp.a -o build/cpp-identity-policy && ./build/cpp-identity-policy` |
| COBOL | `python language/cobol/examples/identity-policy/build.py` |
| D | `dmd -run language/d/examples/identity-policy/identity_policy.d` |
| Dart | `dart language/dart/examples/identity-policy/identity_policy.dart` |
| Delphi / Free Pascal | `fpc -Mobjfpc language/delphi/examples/identity-policy/identity_policy.pas && ./identity_policy` |
| Elixir | `elixir language/elixir/examples/identity-policy/identity_policy.exs` |
| Erlang | `escript language/erlang/examples/identity-policy/identity_policy.escript` |
| Fortran | `gfortran language/fortran/examples/identity-policy/identity_policy_example.f90 -o build/fortran-identity-policy && ./build/fortran-identity-policy` |
| Haskell | `runghc language/haskell/examples/identity-policy/identity_policy.hs` |
| Julia | `julia language/julia/examples/identity-policy/identity_policy.jl` |
| Lua | `lua language/lua/examples/identity-policy/identity_policy.lua` |
| MATLAB / Octave | `octave-cli --path language/matlab/examples/identity-policy --eval identity_policy_example` |
| Nim | `nim r language/nim/examples/identity-policy/identity_policy.nim` |
| Objective-C | `clang -fobjc-arc language/objc/examples/identity-policy/identity_policy.m -framework Foundation -o build/objc-identity-policy && ./build/objc-identity-policy` |
| OCaml | `ocaml language/ocaml/examples/identity-policy/identity_policy.ml` |
| Perl | `perl language/perl/examples/identity-policy/identity_policy.pl` |
| PHP | `php language/php/examples/identity-policy/identity_policy.php` |
| PowerShell | `powershell -File language/powershell/examples/identity-policy/identity_policy.ps1` |
| R | `Rscript language/r/examples/identity-policy/identity_policy.R` |
| Ruby | `ruby -I language/ruby/lib language/ruby/examples/identity-policy/identity_policy.rb` |
| Swift | `swift run --package-path language/swift praxo-identity-policy-example` |
| V | `v run language/v/examples/identity-policy/identity_policy.v` |
| Zig | `zig run language/zig/examples/identity-policy/identity_policy.zig` |

这些是授权模式示例，不是身份提供商或策略决策服务。服务边界上的 Token 验证请参见
[HTTP 嵌入服务教程](embedded-service-tutorial.md)。

## 重要限制

- 工具参数中的角色字符串是不可信输入。Hook 必须使用已验证 principal。
- 身份授权不替代沙箱、最小权限凭据、网络控制或实时安全。
- 审批决定不是持久审批库；绑定、过期、撤销和审计需由应用定义。
- 工具调用成功不证明外部效果已提交。高影响操作需要效果账本或对账。

参见[安全模型](../security/index.md)、[受治理执行设计](../reference/governed-execution.md)
与[采用指南](../getting-started/adoption.md)。
