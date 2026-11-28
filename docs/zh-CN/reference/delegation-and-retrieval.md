# 委派与检索 Seam

这些是可选适配器 seam，不新增持久化 worker 服务、向量数据库或 Core wire 契约。

## 委派

Subagent Manager 管理本地子 run：

- 模式：`isolated` 只带请求启动；`fork` 携带父消息历史。
- 状态：`queued`、`running`、`completed`、`failed`、`canceled`。
- 操作：launch、check、wait、可选中途 update 和 cancel。
- 取消是本地行为，不证明远程工作已停止。
- 终态对本地任务是最终状态，但不是 exactly-once 或持久执行保证。
- Manager 不强制父子 Policy、Tool scope、预算或递归深度收窄。Runner 必须从
  可信父上下文派生 child scope，不能允许 child 放宽。Policy、Tool scope 和
  最终参数重授权仍由 child agent 配置负责。

Go 参考为 `pkg/agent/delegation`。Python 提供
`praxo.delegation.SubagentManager` 和异步 runner seam；TypeScript 提供
`src/delegation.ts` 的 `SubagentManager`；Java 提供
`agent.delegation.SubagentManager`；Rust 提供 `delegation::SubagentManager`；
C# 提供 `Praxo.Core.Delegation.SubagentManager`；R 提供同步 `subagent_run` seam，
没有异步 manager；Ruby 提供 `Delegation::SubagentManager`；PHP 提供同步
`SubagentManager::run` seam；Elixir 提供 `Praxo.SubagentManager`；Lua、C、C++、
Fortran、Haskell、OCaml、Swift、Dart、Perl、D、Delphi/Free Pascal、Objective-C、
Nim、V、Zig、Julia、MATLAB/Octave、Erlang 和 COBOL 提供同步 seam；PowerShell
包装 C# manager。其他实现尚无 in-tree delegation manager。

## 检索

Retriever seam 将 query 和 limit 映射为 documents：

- `Document`：id、content、可选 metadata、可选 score。
- `Retriever`：retrieve query/limit 并返回 documents。
- Function adapter 足以支持本地或调用方自有检索。

Go 参考为 `pkg/retriever`。Python 提供 `praxo.retriever` 的 `Document`、
`Retriever` 和 `FuncRetriever`；TypeScript 提供 `src/retriever.ts` 的同名形状；
Java 提供 `retriever.Document` 和 `retriever.Retriever`；Rust 提供
`retriever::Document` 和 `Retriever`；C# 提供
`Praxo.Core.Retriever.Document` 和 `Retriever`；R 提供 `document` 和
`retriever_retrieve`；Ruby 提供 `Document` 和 `FuncRetriever`；PHP 提供
`Document`、`Retriever` 和 `FuncRetriever`；Elixir 提供 `Praxo.Document` 和
`Praxo.FuncRetriever`；Lua 提供 `document` 和 `retriever_retrieve`；C 提供
`PxDocument` 和 `PxRetriever`；C++ 提供 `Document` 和 `Retriever`；Fortran 提供
`document` 和 `retriever`；Haskell 提供 `Praxo.Retriever.Document` 和
`Retriever`；OCaml 提供 `document` 和 `retrieve_documents`；Swift 提供
`Document`、`FuncRetriever` 和 `retrieveDocuments`；Dart 提供 `Document`、
`FuncRetriever` 和 `retrieveDocuments`；Perl 提供 `document`、`func_retriever`
和 `retrieve_documents`；D 提供 `Document`、`Retriever`、`FuncRetriever` 和
`retrieveDocuments`；Delphi 提供 `TPraxoDocument`、`TPraxoRetriever` 和
`PraxoRetrieveDocuments`；Objective-C 提供 `PXDocument`、`PXRetriever` 和
`PXRetrieveDocuments`；Nim 提供 `Document`、`Retriever`、`FuncRetriever` 和
`retrieveDocuments`；V 提供 `Document`、`Retriever`、`FuncRetriever` 和
`retrieve_documents`；Zig 提供 `retriever.Document`、`retriever.Retriever` 和
`retriever.retrieveDocuments`；Julia 提供 `Document`、`FuncRetriever` 和
`retrieve_documents`；MATLAB 和 GNU Octave 提供共享 `praxo.document` 和
`praxo.retrieve_documents`；Erlang 提供 `praxo_retriever:document`、
`func_retriever` 和 `retrieve/3`；COBOL 提供基于调用方 callback 的
`praxo-retriever`。其他实现尚无 in-tree retriever。

检索不定义 embedding model、vector store、ranking service 或搜索质量承诺。
Memory store 和 context compaction 仍是独立的 Core 表面。

## 基线状态

权威逐语言列表见 [adapter status](../languages/adapter-status.md) 和
[retriever](../languages/adapter-status.md) 表。当前证据是确定性
fixture 或 fake-runner 覆盖，不是 live worker 或真实搜索系统。

## 测试

Delegation 测试覆盖 launch、完成、失败、取消、可选 update、未知任务和校验。
Retrieval 测试覆盖 document 形状、query/limit 转发和 function seam。
