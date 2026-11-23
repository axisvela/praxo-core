# 教程与场景总目录

统一入口：按行业、语言、场景 ID、能力和条目类型查找既有教程与候选场景。
本页由 `scripts/tutorial_catalog.py` 从实际源码路径与场景目录生成，不移动既有文件。

## 计数口径

总目录有 **635 个索引条目**，不是同等数量的独立行业场景或已验证应用。
语言副本、跨语言矩阵、重叠主题与教程切片不能相加为独立场景数。

| 类型 / Type | 数量 / Count |
| --- | ---: |
| 新增候选目标（非实现） | 100 |
| 之前的宽泛场景主题（与新增目标重叠） | 22 |
| 应用教程语言路径 | 33 |
| 跨主题教程指南（与源码入口重叠） | 6 |
| 语言/机制主题源码条目 | 403 |
| 进阶语言/主题源码条目 | 29 |
| 其他源码示例与 recipes | 42 |

完整场景目标：**100**；其中 **43** 个关联已有局部切片；完整实现：**0**。有关联的目标仍是候选，切片关系不额外增加条目计数。

MATLAB/Octave 的两条入口共享实现，不是两个独立场景；未运行原生 MATLAB。
存在 README 与源码只证明入口存在，不证明已运行或通过 CI。运行证据见 [Tutorial 状态](tutorial-plan.md) 与 [验证证据](../project/verification-evidence.md)。

## 按行业与场景

### 软件工程与 IT 运维

候选 ID：`SE-01`, `SE-02`, `SE-03`, `SE-04`, `SE-05`, `SE-06`, `SE-07`, `SE-08`.
旧场景主题：Security / SOC.

| 目标 / Goal | 候选语言 / Targets | 目标状态 / Goal Status | 相关切片 / Related Slices | 完整实现 / Full Implementation |
| --- | --- | --- | --- | --- |
| `SE-01` 端到端全栈代码开发 | TypeScript, Go, Dart | 候选 | - | 未实现 |
| `SE-02` 自动化 Bug 定位与修复 | Python, Rust, Perl | 候选 | [log-triage](https://github.com/axisvela/praxo-core/tree/main/language/perl/Tutorial/log-triage) | 未实现 |
| `SE-03` 遗留代码重构与迁移 | COBOL, Java, Delphi | 候选 | - | 未实现 |
| `SE-04` 单元测试与压测生成 | Java, C#, Haskell | 候选 | - | 未实现 |
| `SE-05` 代码审查、安全与许可证审计 | Rust, OCaml, Go | 候选 | [evidence-vault](https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial/evidence-vault), [soc-alert-triage](https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial/soc-alert-triage) | 未实现 |
| `SE-06` AIOps 自愈与 RCA | Go, Elixir, Erlang | 候选 | [incident-coordination](https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial/incident-coordination), [log-triage](https://github.com/axisvela/praxo-core/tree/main/language/perl/Tutorial/log-triage), [windows-diagnostics](https://github.com/axisvela/praxo-core/tree/main/language/powershell/Tutorial/windows-diagnostics) | 未实现 |
| `SE-07` 云资源与 FinOps 治理 | Ruby, PowerShell, D | 候选 | [finops-review](https://github.com/axisvela/praxo-core/tree/main/language/ruby/Tutorial/finops-review) | 未实现 |
| `SE-08` API 编排与异构集成 | PHP, Java, TypeScript | 候选 | - | 未实现 |

| 教程 / Tutorial | 语言 / Language | 能力 / Capabilities | 相关目标 / Related Goals |
| --- | --- | --- | --- |
| [Go evidence-vault review](https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial/evidence-vault) | go | filesystem,tools,draft,policy | SE-05,PE-03,LJ-01 |
| [Go incident coordination](https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial/incident-coordination) | go | tools,draft,events,policy | SE-06 |
| [Go SOC alert triage](https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial/soc-alert-triage) | go | pii,tools,draft,events,policy | SE-05,PE-03,CY-02,CY-06 |
| [Perl Log Triage](https://github.com/axisvela/praxo-core/tree/main/language/perl/Tutorial/log-triage) | perl | tools,analysis,policy | SE-02,SE-06,CY-03 |
| [Windows Diagnostics Agent](https://github.com/axisvela/praxo-core/tree/main/language/powershell/Tutorial/windows-diagnostics) | powershell | tools,host,policy | SE-06,OP-01 |
| [Ruby FinOps Review (SE-07)](https://github.com/axisvela/praxo-core/tree/main/language/ruby/Tutorial/finops-review) | ruby | analysis,tools,draft,policy | SE-07 |
| [Build a Read-Only Workspace Agent](https://github.com/axisvela/praxo-core/tree/main/docs/guides/workspace-agent-tutorial.md) | go | filesystem,tools,policy | - |

### 企业运营与办公

候选 ID：`OP-01`, `OP-02`, `OP-03`, `OP-04`, `OP-05`, `OP-06`, `OP-07`.
旧场景主题：Knowledge Q&A and document assistant; Office productivity; Procurement / ERP.

| 目标 / Goal | 候选语言 / Targets | 目标状态 / Goal Status | 相关切片 / Related Slices | 完整实现 / Full Implementation |
| --- | --- | --- | --- | --- |
| `OP-01` IT 与 HR 内部服务台 | C#, PHP, PowerShell | 候选 | [order-review](https://github.com/axisvela/praxo-core/tree/main/language/csharp/Tutorial/order-review), [windows-diagnostics](https://github.com/axisvela/praxo-core/tree/main/language/powershell/Tutorial/windows-diagnostics) | 未实现 |
| `OP-02` 会议全生命周期管理 | Dart, Swift, TypeScript | 候选 | - | 未实现 |
| `OP-03` 企业知识库动态维护 | Python, Elixir, OCaml | 候选 | [office-qa](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/office-qa) | 未实现 |
| `OP-04` 跨系统 Agentic RPA | Java, C#, Delphi | 候选 | - | 未实现 |
| `OP-05` 招聘与人才匹配 | Ruby, PHP, Python | 候选 | - | 未实现 |
| `OP-06` 个性化入职导师 | Python, Dart, Swift | 候选 | [office-qa](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/office-qa) | 未实现 |
| `OP-07` 高管经营简报 | R, Julia, D | 候选 | - | 未实现 |

| 教程 / Tutorial | 语言 / Language | 能力 / Capabilities | 相关目标 / Related Goals |
| --- | --- | --- | --- |
| [Windows Diagnostics Agent](https://github.com/axisvela/praxo-core/tree/main/language/powershell/Tutorial/windows-diagnostics) | powershell | tools,host,policy | SE-06,OP-01 |
| [Python Office Q&A](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/office-qa) | python | retrieval,citations,policy | OP-03,OP-06,MD-02 |

### 客服、营销与商业

候选 ID：`CS-01`, `CS-02`, `CS-03`, `CS-04`, `CS-05`, `CS-06`, `CS-07`.
旧场景主题：Customer service / contact center; Marketing content and segmentation; Sales / CRM; Media / content; Retail / e-commerce.

| 目标 / Goal | 候选语言 / Targets | 目标状态 / Goal Status | 相关切片 / Related Slices | 完整实现 / Full Implementation |
| --- | --- | --- | --- | --- |
| `CS-01` 多模态全渠道客服 | TypeScript, C#, PHP | 候选 | [order-review](https://github.com/axisvela/praxo-core/tree/main/language/csharp/Tutorial/order-review), [order-review](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/order-review), [order-review](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/order-review), [customer-support](https://github.com/axisvela/praxo-core/tree/main/language/typescript/Tutorial/customer-support), [order-review](https://github.com/axisvela/praxo-core/tree/main/language/typescript/Tutorial/order-review) | 未实现 |
| `CS-02` B2B 潜客与线索培育 | Ruby, PHP, Elixir | 候选 | - | 未实现 |
| `CS-03` 销售通话辅助与复盘 | C#, Swift, TypeScript | 候选 | [sales-crm](https://github.com/axisvela/praxo-core/tree/main/language/csharp/Tutorial/sales-crm) | 未实现 |
| `CS-04` 内容营销与矩阵运营 | Python, R, Dart | 候选 | [marketing-segmentation](https://github.com/axisvela/praxo-core/tree/main/language/r/Tutorial/marketing-segmentation) | 未实现 |
| `CS-05` 电商定价与补货 | Java, PHP, Ruby | 候选 | [order-review](https://github.com/axisvela/praxo-core/tree/main/language/csharp/Tutorial/order-review), [order-review](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/order-review), [order-review](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/order-review), [order-review](https://github.com/axisvela/praxo-core/tree/main/language/typescript/Tutorial/order-review) | 未实现 |
| `CS-06` 流失预警与主动挽留 | R, Elixir, Julia | 候选 | [marketing-segmentation](https://github.com/axisvela/praxo-core/tree/main/language/r/Tutorial/marketing-segmentation) | 未实现 |
| `CS-07` 跨境多语言本地化 | TypeScript, PHP, Perl | 候选 | - | 未实现 |

| 教程 / Tutorial | 语言 / Language | 能力 / Capabilities | 相关目标 / Related Goals |
| --- | --- | --- | --- |
| [C# Order Service Desk](https://github.com/axisvela/praxo-core/tree/main/language/csharp/Tutorial/order-review) | csharp | tools,policy,http | CS-01,CS-05 |
| [C# Sales / CRM Service Desk](https://github.com/axisvela/praxo-core/tree/main/language/csharp/Tutorial/sales-crm) | csharp | tools,draft,http,policy | CS-03 |
| [Java Order Review Web Agent](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/order-review) | java | tools,policy,http | CS-01,CS-05 |
| [Order Review Agent](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/order-review) | python | tools,policy,http | CS-01,CS-05 |
| [R marketing segmentation](https://github.com/axisvela/praxo-core/tree/main/language/r/Tutorial/marketing-segmentation) | r | analysis,tools,draft,policy | CS-04,CS-06 |
| [TypeScript Customer Support Streaming](https://github.com/axisvela/praxo-core/tree/main/language/typescript/Tutorial/customer-support) | typescript | streaming,citations,http,policy | CS-01 |
| [Order Support Agent](https://github.com/axisvela/praxo-core/tree/main/language/typescript/Tutorial/order-review) | typescript | tools,policy,http | CS-01,CS-05 |

### 金融、财税与合规

候选 ID：`FC-01`, `FC-02`, `FC-03`, `FC-04`, `FC-05`, `FC-06`.
旧场景主题：Wealth / retail finance; Insurance claims; Legal / compliance.

| 目标 / Goal | 候选语言 / Targets | 目标状态 / Goal Status | 相关切片 / Related Slices | 完整实现 / Full Implementation |
| --- | --- | --- | --- | --- |
| `FC-01` 投研与财报分析 | R, Julia, Java | 候选 | [wealth-service](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/wealth-service), [wealth-analysis](https://github.com/axisvela/praxo-core/tree/main/language/r/Tutorial/wealth-analysis) | 未实现 |
| `FC-02` 量化执行与风险控制 | C++, Rust, D | 候选 | [wealth-service](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/wealth-service), [wealth-analysis](https://github.com/axisvela/praxo-core/tree/main/language/r/Tutorial/wealth-analysis) | 未实现 |
| `FC-03` 信贷尽调与反欺诈 | Java, COBOL, Python | 候选 | [batch-exception-review](https://github.com/axisvela/praxo-core/tree/main/language/cobol/Tutorial/batch-exception-review) | 未实现 |
| `FC-04` 税务筹划与申报 | COBOL, Java, Delphi | 候选 | [batch-exception-review](https://github.com/axisvela/praxo-core/tree/main/language/cobol/Tutorial/batch-exception-review) | 未实现 |
| `FC-05` 合同全生命周期审查 | Python, OCaml, C# | 候选 | [legal-compliance](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/legal-compliance) | 未实现 |
| `FC-06` 监管追踪与内控审计 | Python, R, Perl | 候选 | [legal-compliance](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/legal-compliance) | 未实现 |

| 教程 / Tutorial | 语言 / Language | 能力 / Capabilities | 相关目标 / Related Goals |
| --- | --- | --- | --- |
| [COBOL Bank Batch Exception Review](https://github.com/axisvela/praxo-core/tree/main/language/cobol/Tutorial/batch-exception-review) | cobol | batch,tools,policy | FC-03,FC-04 |
| [Java Wealth Review Service](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/wealth-service) | java | tools,draft,http,policy | FC-01,FC-02 |
| [Python insurance claims triage](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/insurance-claims) | python | structured-output,analysis,tools,draft,policy | - |
| [Python legal compliance memo](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/legal-compliance) | python | citations,approval,tools,policy | FC-05,FC-06,LJ-04 |
| [R wealth analysis](https://github.com/axisvela/praxo-core/tree/main/language/r/Tutorial/wealth-analysis) | r | analysis,tools,draft,policy | FC-01,FC-02 |

### 科研与数据分析

候选 ID：`SC-01`, `SC-02`, `SC-03`, `SC-04`, `SC-05`, `SC-06`.
旧场景主题：Data platform.

| 目标 / Goal | 候选语言 / Targets | 目标状态 / Goal Status | 相关切片 / Related Slices | 完整实现 / Full Implementation |
| --- | --- | --- | --- | --- |
| `SC-01` 文献综述与假设生成 | Python, Julia, Haskell | 候选 | - | 未实现 |
| `SC-02` 制药与分子设计 | Python, Julia, C++ | 候选 | - | 未实现 |
| `SC-03` 自动化实验室 | Julia, Rust, C | 候选 | - | 未实现 |
| `SC-04` 材料逆向设计与仿真 | Fortran, Julia, C++ | 候选 | [simulation-metrics](https://github.com/axisvela/praxo-core/tree/main/language/fortran/Tutorial/simulation-metrics) | 未实现 |
| `SC-05` 气象建模与天气预警 | Fortran, R, Octave | 候选 | [signal-trends](https://github.com/axisvela/praxo-core/tree/main/language/matlab/Tutorial/signal-trends), [signal-trends](https://github.com/axisvela/praxo-core/tree/main/language/octave/Tutorial/signal-trends) | 未实现 |
| `SC-06` 科研清洗与统计建模 | R, Julia, MATLAB | 候选 | [simulation-metrics](https://github.com/axisvela/praxo-core/tree/main/language/fortran/Tutorial/simulation-metrics), [experiment-comparison](https://github.com/axisvela/praxo-core/tree/main/language/julia/Tutorial/experiment-comparison), [data-quality](https://github.com/axisvela/praxo-core/tree/main/language/r/Tutorial/data-quality) | 未实现 |

| 教程 / Tutorial | 语言 / Language | 能力 / Capabilities | 相关目标 / Related Goals |
| --- | --- | --- | --- |
| [Fortran simulation metrics review](https://github.com/axisvela/praxo-core/tree/main/language/fortran/Tutorial/simulation-metrics) | fortran | analysis,tools,draft,policy | SC-04,SC-06 |
| [Julia Experiment Comparison Agent](https://github.com/axisvela/praxo-core/tree/main/language/julia/Tutorial/experiment-comparison) | julia | analysis,tools,policy | SC-06 |
| [Signal Trends Agent](https://github.com/axisvela/praxo-core/tree/main/language/matlab/Tutorial/signal-trends) | matlab | analysis,tools,policy | SC-05,IN-01,CT-02,TL-04 |
| [Octave Signal Trends](https://github.com/axisvela/praxo-core/tree/main/language/octave/Tutorial/signal-trends) | octave | analysis,tools,policy | SC-05,IN-01,CT-02,TL-04 |
| [R Data Quality Agent](https://github.com/axisvela/praxo-core/tree/main/language/r/Tutorial/data-quality) | r | analysis,tools,policy | SC-06 |
| [Python Structured Output Application](https://github.com/axisvela/praxo-core/tree/main/docs/guides/python-structured-output-app.md) | python | structured-output,batch,checkpoint | - |

### 工业、供应链与能源

候选 ID：`IN-01`, `IN-02`, `IN-03`, `IN-04`, `IN-05`, `IN-06`.
旧场景主题：Factory / manufacturing; Industrial automation; Consumer electronics; Logistics; Energy / grid.

| 目标 / Goal | 候选语言 / Targets | 目标状态 / Goal Status | 相关切片 / Related Slices | 完整实现 / Full Implementation |
| --- | --- | --- | --- | --- |
| `IN-01` 预测维护与检修排程 | C++, Rust, Nim | 候选 | [device-diagnostics](https://github.com/axisvela/praxo-core/tree/main/language/c/Tutorial/device-diagnostics), [industrial-edge](https://github.com/axisvela/praxo-core/tree/main/language/cpp/Tutorial/industrial-edge), [signal-trends](https://github.com/axisvela/praxo-core/tree/main/language/matlab/Tutorial/signal-trends), [signal-trends](https://github.com/axisvela/praxo-core/tree/main/language/octave/Tutorial/signal-trends), [iot-gateway](https://github.com/axisvela/praxo-core/tree/main/language/rust/Tutorial/iot-gateway), [gateway-health](https://github.com/axisvela/praxo-core/tree/main/language/zig/Tutorial/gateway-health) | 未实现 |
| `IN-02` 柔性产线动态排产 | Erlang, C++, V | 候选 | - | 未实现 |
| `IN-03` 供应链断链预警与寻源 | Go, Java, Ruby | 候选 | [logistics-checkpoint](https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial/logistics-checkpoint) | 未实现 |
| `IN-04` 微网调度与负荷平衡 | Julia, Fortran, Zig | 候选 | [gateway-health](https://github.com/axisvela/praxo-core/tree/main/language/zig/Tutorial/gateway-health) | 未实现 |
| `IN-05` 图纸审查与 BOM | C++, C#, OCaml | 候选 | - | 未实现 |
| `IN-06` 精准灌溉与病虫害防治 | C, Lua, Nim | 候选 | [device-diagnostics](https://github.com/axisvela/praxo-core/tree/main/language/c/Tutorial/device-diagnostics), [host-embedding](https://github.com/axisvela/praxo-core/tree/main/language/lua/Tutorial/host-embedding), [iot-gateway](https://github.com/axisvela/praxo-core/tree/main/language/rust/Tutorial/iot-gateway) | 未实现 |

| 教程 / Tutorial | 语言 / Language | 能力 / Capabilities | 相关目标 / Related Goals |
| --- | --- | --- | --- |
| [C constrained host diagnostic component](https://github.com/axisvela/praxo-core/tree/main/language/c/Tutorial/device-diagnostics) | c | host,tools,draft,policy | IN-01,IN-06 |
| [C++ industrial edge maintenance](https://github.com/axisvela/praxo-core/tree/main/language/cpp/Tutorial/industrial-edge) | cpp | host,tools,draft,policy | IN-01 |
| [Go logistics checkpoint and resume](https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial/logistics-checkpoint) | go | checkpoint,tools,draft,policy | IN-03,TL-05,OG-06 |
| [Lua Host Embedding](https://github.com/axisvela/praxo-core/tree/main/language/lua/Tutorial/host-embedding) | lua | host,tools,draft,policy | IN-06,PE-05,MD-03,AE-03 |
| [Signal Trends Agent](https://github.com/axisvela/praxo-core/tree/main/language/matlab/Tutorial/signal-trends) | matlab | analysis,tools,policy | SC-05,IN-01,CT-02,TL-04 |
| [Octave Signal Trends](https://github.com/axisvela/praxo-core/tree/main/language/octave/Tutorial/signal-trends) | octave | analysis,tools,policy | SC-05,IN-01,CT-02,TL-04 |
| [Rust IoT gateway diagnosis](https://github.com/axisvela/praxo-core/tree/main/language/rust/Tutorial/iot-gateway) | rust | host,tools,draft,policy | IN-01,IN-06 |
| [Zig small gateway health check](https://github.com/axisvela/praxo-core/tree/main/language/zig/Tutorial/gateway-health) | zig | host,tools,draft,policy | IN-01,IN-04 |

### 医疗健康

候选 ID：`HC-01`, `HC-02`, `HC-03`, `HC-04`, `HC-05`.
旧场景主题：Healthcare scheduling.

| 目标 / Goal | 候选语言 / Targets | 目标状态 / Goal Status | 相关切片 / Related Slices | 完整实现 / Full Implementation |
| --- | --- | --- | --- | --- |
| `HC-01` 临床辅助与 MDT | Python, Java, R | 候选 | - | 未实现 |
| `HC-02` 慢病管理与随访 | Swift, Dart, Objective-C | 候选 | - | 未实现 |
| `HC-03` 临床试验招募匹配 | Python, Java, C# | 候选 | - | 未实现 |
| `HC-04` 病历质控与 DRG/DIP 编码 | Java, COBOL, C# | 候选 | - | 未实现 |
| `HC-05` 心理支持与 CBT 练习 | Swift, Dart, Python | 候选 | - | 未实现 |

| 教程 / Tutorial | 语言 / Language | 能力 / Capabilities | 相关目标 / Related Goals |
| --- | --- | --- | --- |
| [C# healthcare scheduling](https://github.com/axisvela/praxo-core/tree/main/language/csharp/Tutorial/healthcare-scheduling) | csharp | tools,draft,policy | - |

### 个人、教育与具身

候选 ID：`PE-01`, `PE-02`, `PE-03`, `PE-04`, `PE-05`.
旧场景主题：Robotics; Education / tutoring; Travel / booking.

| 目标 / Goal | 候选语言 / Targets | 目标状态 / Goal Status | 相关切片 / Related Slices | 完整实现 / Full Implementation |
| --- | --- | --- | --- | --- |
| `PE-01` 苏格拉底式学习导师 | Python, TypeScript, Haskell | 候选 | [education-tutoring](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/education-tutoring) | 未实现 |
| `PE-02` 差旅与生活全案管家 | TypeScript, Dart, Swift | 候选 | [travel-booking](https://github.com/axisvela/praxo-core/tree/main/language/typescript/Tutorial/travel-booking) | 未实现 |
| `PE-03` 数字信息与隐私代理 | Rust, Go, Objective-C | 候选 | [evidence-vault](https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial/evidence-vault), [soc-alert-triage](https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial/soc-alert-triage) | 未实现 |
| `PE-04` 人形机器人与家庭服务 | C++, Rust, Zig | 候选 | - | 未实现 |
| `PE-05` 游戏 NPC 与动态叙事 | Lua, C, V | 候选 | [host-embedding](https://github.com/axisvela/praxo-core/tree/main/language/lua/Tutorial/host-embedding) | 未实现 |

| 教程 / Tutorial | 语言 / Language | 能力 / Capabilities | 相关目标 / Related Goals |
| --- | --- | --- | --- |
| [Go evidence-vault review](https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial/evidence-vault) | go | filesystem,tools,draft,policy | SE-05,PE-03,LJ-01 |
| [Go SOC alert triage](https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial/soc-alert-triage) | go | pii,tools,draft,events,policy | SE-05,PE-03,CY-02,CY-06 |
| [Lua Host Embedding](https://github.com/axisvela/praxo-core/tree/main/language/lua/Tutorial/host-embedding) | lua | host,tools,draft,policy | IN-06,PE-05,MD-03,AE-03 |
| [Python education tutoring](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/education-tutoring) | python | retrieval,citations,tools,draft,policy | PE-01 |
| [TypeScript travel booking](https://github.com/axisvela/praxo-core/tree/main/language/typescript/Tutorial/travel-booking) | typescript | tools,draft,policy | PE-02,TL-07 |

### 网络安全与攻防对抗

候选 ID：`CY-01`, `CY-02`, `CY-03`, `CY-04`, `CY-05`, `CY-06`, `CY-07`.
旧场景主题：-.

| 目标 / Goal | 候选语言 / Targets | 目标状态 / Goal Status | 相关切片 / Related Slices | 完整实现 / Full Implementation |
| --- | --- | --- | --- | --- |
| `CY-01` 自动化渗透测试与红队演练 | Rust, Go, Python | 候选 | - | 未实现 |
| `CY-02` SOC 告警研判与 SOAR 响应 | Go, Elixir, Erlang | 候选 | [soc-alert-triage](https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial/soc-alert-triage) | 未实现 |
| `CY-03` 威胁狩猎与 TTP 还原 | Perl, Rust, Python | 候选 | [log-triage](https://github.com/axisvela/praxo-core/tree/main/language/perl/Tutorial/log-triage) | 未实现 |
| `CY-04` 钓鱼识别与反钓鱼演练 | Python, TypeScript, C# | 候选 | - | 未实现 |
| `CY-05` 零信任策略动态调优 | Java, C#, Go | 候选 | - | 未实现 |
| `CY-06` DLP 与隐私脱敏 | Go, Rust, Objective-C | 候选 | [soc-alert-triage](https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial/soc-alert-triage) | 未实现 |
| `CY-07` 开源供应链投毒监测 | Rust, OCaml, Ruby | 候选 | - | 未实现 |

| 教程 / Tutorial | 语言 / Language | 能力 / Capabilities | 相关目标 / Related Goals |
| --- | --- | --- | --- |
| [Go SOC alert triage](https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial/soc-alert-triage) | go | pii,tools,draft,events,policy | SE-05,PE-03,CY-02,CY-06 |
| [Perl Log Triage](https://github.com/axisvela/praxo-core/tree/main/language/perl/Tutorial/log-triage) | perl | tools,analysis,policy | SE-02,SE-06,CY-03 |

### 智慧城市与公共治理

候选 ID：`CT-01`, `CT-02`, `CT-03`, `CT-04`, `CT-05`, `CT-06`, `CT-07`.
旧场景主题：-.

| 目标 / Goal | 候选语言 / Targets | 目标状态 / Goal Status | 相关切片 / Related Slices | 完整实现 / Full Implementation |
| --- | --- | --- | --- | --- |
| `CT-01` 城市信号灯全域协同 | Erlang, C++, Julia | 候选 | - | 未实现 |
| `CT-02` 生命线管网泄漏定位与调度 | Fortran, Rust, Nim | 候选 | [signal-trends](https://github.com/axisvela/praxo-core/tree/main/language/matlab/Tutorial/signal-trends), [signal-trends](https://github.com/axisvela/praxo-core/tree/main/language/octave/Tutorial/signal-trends) | 未实现 |
| `CT-03` 政务跨部门审批 | Java, C#, PHP | 候选 | - | 未实现 |
| `CT-04` 应急指挥与资源调度 | Go, Julia, Erlang | 候选 | - | 未实现 |
| `CT-05` 污染溯源与执法辅助 | R, Fortran, Python | 候选 | - | 未实现 |
| `CT-06` 垃圾分类与清运优化 | Julia, Dart, V | 候选 | - | 未实现 |
| `CT-07` 公共预算执行与绩效 | R, COBOL, Java | 候选 | - | 未实现 |

| 教程 / Tutorial | 语言 / Language | 能力 / Capabilities | 相关目标 / Related Goals |
| --- | --- | --- | --- |
| [Signal Trends Agent](https://github.com/axisvela/praxo-core/tree/main/language/matlab/Tutorial/signal-trends) | matlab | analysis,tools,policy | SC-05,IN-01,CT-02,TL-04 |
| [Octave Signal Trends](https://github.com/axisvela/praxo-core/tree/main/language/octave/Tutorial/signal-trends) | octave | analysis,tools,policy | SC-05,IN-01,CT-02,TL-04 |

### 交通物流、航运与低空经济

候选 ID：`TL-01`, `TL-02`, `TL-03`, `TL-04`, `TL-05`, `TL-06`, `TL-07`.
旧场景主题：-.

| 目标 / Goal | 候选语言 / Targets | 目标状态 / Goal Status | 相关切片 / Related Slices | 完整实现 / Full Implementation |
| --- | --- | --- | --- | --- |
| `TL-01` 无人机集群巡检与空域消冲 | Rust, C++, Zig | 候选 | - | 未实现 |
| `TL-02` 集装箱堆场与岸桥协同 | Erlang, C++, Java | 候选 | - | 未实现 |
| `TL-03` 远洋气象导航与燃油优化 | Fortran, Julia, C++ | 候选 | - | 未实现 |
| `TL-04` 冷链温控与货损预警 | Rust, Nim, Octave | 候选 | [signal-trends](https://github.com/axisvela/praxo-core/tree/main/language/matlab/Tutorial/signal-trends), [signal-trends](https://github.com/axisvela/praxo-core/tree/main/language/octave/Tutorial/signal-trends) | 未实现 |
| `TL-05` 多式联运报关与路径重算 | Java, Go, PHP | 候选 | [logistics-checkpoint](https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial/logistics-checkpoint) | 未实现 |
| `TL-06` 自动驾驶远程脱困与地图更新 | C++, Rust, D | 候选 | - | 未实现 |
| `TL-07` 机场机位与延误恢复 | Java, Julia, C# | 候选 | [travel-booking](https://github.com/axisvela/praxo-core/tree/main/language/typescript/Tutorial/travel-booking) | 未实现 |

| 教程 / Tutorial | 语言 / Language | 能力 / Capabilities | 相关目标 / Related Goals |
| --- | --- | --- | --- |
| [Go logistics checkpoint and resume](https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial/logistics-checkpoint) | go | checkpoint,tools,draft,policy | IN-03,TL-05,OG-06 |
| [Signal Trends Agent](https://github.com/axisvela/praxo-core/tree/main/language/matlab/Tutorial/signal-trends) | matlab | analysis,tools,policy | SC-05,IN-01,CT-02,TL-04 |
| [Octave Signal Trends](https://github.com/axisvela/praxo-core/tree/main/language/octave/Tutorial/signal-trends) | octave | analysis,tools,policy | SC-05,IN-01,CT-02,TL-04 |
| [TypeScript travel booking](https://github.com/axisvela/praxo-core/tree/main/language/typescript/Tutorial/travel-booking) | typescript | tools,draft,policy | PE-02,TL-07 |

### 传媒、设计、游戏与数字内容

候选 ID：`MD-01`, `MD-02`, `MD-03`, `MD-04`, `MD-05`, `MD-06`, `MD-07`.
旧场景主题：-.

| 目标 / Goal | 候选语言 / Targets | 目标状态 / Goal Status | 相关切片 / Related Slices | 完整实现 / Full Implementation |
| --- | --- | --- | --- | --- |
| `MD-01` 影视分镜与虚拟制片预演 | Lua, C++, TypeScript | 候选 | - | 未实现 |
| `MD-02` 新闻事实核查与多源验证 | Python, Haskell, Perl | 候选 | [office-qa](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/office-qa) | 未实现 |
| `MD-03` 开放世界游戏生态演化 | Lua, C, V | 候选 | [host-embedding](https://github.com/axisvela/praxo-core/tree/main/language/lua/Tutorial/host-embedding) | 未实现 |
| `MD-04` 配音、口型同步与文化本地化 | Python, Swift, C++ | 候选 | - | 未实现 |
| `MD-05` 工业设计与 3D 拓扑生成 | C++, Julia, Fortran | 候选 | - | 未实现 |
| `MD-06` 有声书与沉浸广播剧制作 | Python, Dart, Swift | 候选 | - | 未实现 |
| `MD-07` 数字人直播互动场控 | TypeScript, Elixir, Lua | 候选 | - | 未实现 |

| 教程 / Tutorial | 语言 / Language | 能力 / Capabilities | 相关目标 / Related Goals |
| --- | --- | --- | --- |
| [Lua Host Embedding](https://github.com/axisvela/praxo-core/tree/main/language/lua/Tutorial/host-embedding) | lua | host,tools,draft,policy | IN-06,PE-05,MD-03,AE-03 |
| [Python Office Q&A](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/office-qa) | python | retrieval,citations,policy | OP-03,OP-06,MD-02 |

### 法律、司法与知识产权

候选 ID：`LJ-01`, `LJ-02`, `LJ-03`, `LJ-04`, `LJ-05`.
旧场景主题：-.

| 目标 / Goal | 候选语言 / Targets | 目标状态 / Goal Status | 相关切片 / Related Slices | 完整实现 / Full Implementation |
| --- | --- | --- | --- | --- |
| `LJ-01` 诉讼证据链与质证提纲 | Python, OCaml, Go | 候选 | [evidence-vault](https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial/evidence-vault) | 未实现 |
| `LJ-02` 专利检索、FTO 与布局 | Python, Java, Haskell | 候选 | - | 未实现 |
| `LJ-03` 商业尽职调查 | Java, C#, Ruby | 候选 | - | 未实现 |
| `LJ-04` 类案检索与法律文书草拟 | Python, Java, OCaml | 候选 | [legal-compliance](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/legal-compliance) | 未实现 |
| `LJ-05` 数字版权监测与维权流程 | Rust, PHP, TypeScript | 候选 | - | 未实现 |

| 教程 / Tutorial | 语言 / Language | 能力 / Capabilities | 相关目标 / Related Goals |
| --- | --- | --- | --- |
| [Go evidence-vault review](https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial/evidence-vault) | go | filesystem,tools,draft,policy | SE-05,PE-03,LJ-01 |
| [Python legal compliance memo](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/legal-compliance) | python | citations,approval,tools,policy | FC-05,FC-06,LJ-04 |

### 建筑工程、矿业与空间运营

候选 ID：`BE-01`, `BE-02`, `BE-03`, `BE-04`, `BE-05`.
旧场景主题：-.

| 目标 / Goal | 候选语言 / Targets | 目标状态 / Goal Status | 相关切片 / Related Slices | 完整实现 / Full Implementation |
| --- | --- | --- | --- | --- |
| `BE-01` 工地安全巡检与整改复核 | C++, Rust, C# | 候选 | - | 未实现 |
| `BE-02` 商业楼宇 HVAC 与照明节能 | Julia, C, Delphi | 候选 | - | 未实现 |
| `BE-03` 智慧矿山与边坡风险预警 | Fortran, Rust, C++ | 候选 | - | 未实现 |
| `BE-04` 招投标编制与串标审查 | Java, PHP, COBOL | 候选 | - | 未实现 |
| `BE-05` 地产选址与租金预测 | R, Julia, D | 候选 | - | 未实现 |

| 教程 / Tutorial | 语言 / Language | 能力 / Capabilities | 相关目标 / Related Goals |
| --- | --- | --- | --- |

### 农业、林业与生态保护

候选 ID：`AE-01`, `AE-02`, `AE-03`, `AE-04`, `AE-05`.
旧场景主题：-.

| 目标 / Goal | 候选语言 / Targets | 目标状态 / Goal Status | 相关切片 / Related Slices | 完整实现 / Full Implementation |
| --- | --- | --- | --- | --- |
| `AE-01` 畜牧健康监测与精准饲喂 | C, Nim, Rust | 候选 | - | 未实现 |
| `AE-02` 森林火险与蔓延推演 | Fortran, Julia, R | 候选 | - | 未实现 |
| `AE-03` 海洋牧场水质与投饵 | Lua, C, Octave | 候选 | [host-embedding](https://github.com/axisvela/praxo-core/tree/main/language/lua/Tutorial/host-embedding) | 未实现 |
| `AE-04` 农产品套保与产销规划 | R, Julia, COBOL | 候选 | - | 未实现 |
| `AE-05` 生物多样性与盗猎预警 | Python, Rust, Zig | 候选 | - | 未实现 |

| 教程 / Tutorial | 语言 / Language | 能力 / Capabilities | 相关目标 / Related Goals |
| --- | --- | --- | --- |
| [Lua Host Embedding](https://github.com/axisvela/praxo-core/tree/main/language/lua/Tutorial/host-embedding) | lua | host,tools,draft,policy | IN-06,PE-05,MD-03,AE-03 |

### 组织治理、架构与跨学科协同

候选 ID：`OG-01`, `OG-02`, `OG-03`, `OG-04`, `OG-05`, `OG-06`, `OG-07`.
旧场景主题：-.

| 目标 / Goal | 候选语言 / Targets | 目标状态 / Goal Status | 相关切片 / Related Slices | 完整实现 / Full Implementation |
| --- | --- | --- | --- | --- |
| `OG-01` EA 资产图谱治理 | Java, OCaml, C# | 候选 | - | 未实现 |
| `OG-02` 多智能体社会与政策沙盘 | Julia, Erlang, Haskell | 候选 | - | 未实现 |
| `OG-03` 跨文化谈判同传与策略辅助 | TypeScript, Swift, Python | 候选 | - | 未实现 |
| `OG-04` 开源社区治理与贡献者体验 | Ruby, Elixir, Perl | 候选 | - | 未实现 |
| `OG-05` EDA 布局布线优化 | C++, Fortran, Julia | 候选 | - | 未实现 |
| `OG-06` 个人数字孪生与跨应用记忆 | Swift, Objective-C, Dart | 候选 | [logistics-checkpoint](https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial/logistics-checkpoint) | 未实现 |
| `OG-07` 多学科 Virtual PI | Python, Julia, Haskell | 候选 | [representative-chain](https://github.com/axisvela/praxo-core/tree/main/examples/representative-chain) | 未实现 |

| 教程 / Tutorial | 语言 / Language | 能力 / Capabilities | 相关目标 / Related Goals |
| --- | --- | --- | --- |
| [Go logistics checkpoint and resume](https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial/logistics-checkpoint) | go | checkpoint,tools,draft,policy | IN-03,TL-05,OG-06 |

完整的 100 个目标与语言候选分配见 [场景目录](agent-scenarios.md)；旧主题和状态仍见 [Tutorial Plan](tutorial-plan.md)。相关目标不表示完整目标已实现。

## 按语言

| Core | 应用教程 / Application Paths | 机制 / Mechanisms | 进阶 / Advanced | 其他源码 / Other Source |
| --- | --- | ---: | ---: | ---: |
| [c](https://github.com/axisvela/praxo-core/tree/main/language/c) | [device-diagnostics](https://github.com/axisvela/praxo-core/tree/main/language/c/Tutorial/device-diagnostics) | 13 | 0 | 0 |
| [cobol](https://github.com/axisvela/praxo-core/tree/main/language/cobol) | [batch-exception-review](https://github.com/axisvela/praxo-core/tree/main/language/cobol/Tutorial/batch-exception-review) | 13 | 0 | 1 |
| [cpp](https://github.com/axisvela/praxo-core/tree/main/language/cpp) | [industrial-edge](https://github.com/axisvela/praxo-core/tree/main/language/cpp/Tutorial/industrial-edge) | 13 | 0 | 0 |
| [csharp](https://github.com/axisvela/praxo-core/tree/main/language/csharp) | [healthcare-scheduling](https://github.com/axisvela/praxo-core/tree/main/language/csharp/Tutorial/healthcare-scheduling), [order-review](https://github.com/axisvela/praxo-core/tree/main/language/csharp/Tutorial/order-review), [sales-crm](https://github.com/axisvela/praxo-core/tree/main/language/csharp/Tutorial/sales-crm) | 13 | 1 | 0 |
| [d](https://github.com/axisvela/praxo-core/tree/main/language/d) | - | 13 | 1 | 1 |
| [dart](https://github.com/axisvela/praxo-core/tree/main/language/dart) | - | 13 | 1 | 1 |
| [delphi](https://github.com/axisvela/praxo-core/tree/main/language/delphi) | - | 13 | 1 | 1 |
| [elixir](https://github.com/axisvela/praxo-core/tree/main/language/elixir) | - | 13 | 1 | 1 |
| [erlang](https://github.com/axisvela/praxo-core/tree/main/language/erlang) | - | 13 | 1 | 1 |
| [fortran](https://github.com/axisvela/praxo-core/tree/main/language/fortran) | [simulation-metrics](https://github.com/axisvela/praxo-core/tree/main/language/fortran/Tutorial/simulation-metrics) | 13 | 0 | 0 |
| [go](https://github.com/axisvela/praxo-core/tree/main/language/go) | [evidence-vault](https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial/evidence-vault), [incident-coordination](https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial/incident-coordination), [logistics-checkpoint](https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial/logistics-checkpoint), [soc-alert-triage](https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial/soc-alert-triage) | 13 | 3 | 14 |
| [haskell](https://github.com/axisvela/praxo-core/tree/main/language/haskell) | - | 13 | 1 | 1 |
| [java](https://github.com/axisvela/praxo-core/tree/main/language/java) | [order-review](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/order-review), [wealth-service](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/wealth-service) | 13 | 1 | 0 |
| [julia](https://github.com/axisvela/praxo-core/tree/main/language/julia) | [experiment-comparison](https://github.com/axisvela/praxo-core/tree/main/language/julia/Tutorial/experiment-comparison) | 13 | 1 | 1 |
| [lua](https://github.com/axisvela/praxo-core/tree/main/language/lua) | [host-embedding](https://github.com/axisvela/praxo-core/tree/main/language/lua/Tutorial/host-embedding) | 13 | 1 | 1 |
| [matlab](https://github.com/axisvela/praxo-core/tree/main/language/matlab) | [signal-trends](https://github.com/axisvela/praxo-core/tree/main/language/matlab/Tutorial/signal-trends) | 13 | 1 | 1 |
| [nim](https://github.com/axisvela/praxo-core/tree/main/language/nim) | - | 13 | 1 | 1 |
| [objc](https://github.com/axisvela/praxo-core/tree/main/language/objc) | - | 13 | 1 | 1 |
| [ocaml](https://github.com/axisvela/praxo-core/tree/main/language/ocaml) | - | 13 | 1 | 1 |
| [octave](https://github.com/axisvela/praxo-core/tree/main/language/octave) | [signal-trends](https://github.com/axisvela/praxo-core/tree/main/language/octave/Tutorial/signal-trends) | 13 | 1 | 1 |
| [perl](https://github.com/axisvela/praxo-core/tree/main/language/perl) | [log-triage](https://github.com/axisvela/praxo-core/tree/main/language/perl/Tutorial/log-triage) | 13 | 1 | 1 |
| [php](https://github.com/axisvela/praxo-core/tree/main/language/php) | - | 13 | 1 | 1 |
| [powershell](https://github.com/axisvela/praxo-core/tree/main/language/powershell) | [windows-diagnostics](https://github.com/axisvela/praxo-core/tree/main/language/powershell/Tutorial/windows-diagnostics) | 13 | 1 | 1 |
| [python](https://github.com/axisvela/praxo-core/tree/main/language/python) | [education-tutoring](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/education-tutoring), [insurance-claims](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/insurance-claims), [legal-compliance](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/legal-compliance), [office-qa](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/office-qa), [order-review](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/order-review) | 13 | 1 | 3 |
| [r](https://github.com/axisvela/praxo-core/tree/main/language/r) | [data-quality](https://github.com/axisvela/praxo-core/tree/main/language/r/Tutorial/data-quality), [marketing-segmentation](https://github.com/axisvela/praxo-core/tree/main/language/r/Tutorial/marketing-segmentation), [wealth-analysis](https://github.com/axisvela/praxo-core/tree/main/language/r/Tutorial/wealth-analysis) | 13 | 1 | 1 |
| [ruby](https://github.com/axisvela/praxo-core/tree/main/language/ruby) | [finops-review](https://github.com/axisvela/praxo-core/tree/main/language/ruby/Tutorial/finops-review) | 13 | 1 | 1 |
| [rust](https://github.com/axisvela/praxo-core/tree/main/language/rust) | [iot-gateway](https://github.com/axisvela/praxo-core/tree/main/language/rust/Tutorial/iot-gateway) | 13 | 1 | 1 |
| [swift](https://github.com/axisvela/praxo-core/tree/main/language/swift) | - | 13 | 1 | 1 |
| [typescript](https://github.com/axisvela/praxo-core/tree/main/language/typescript) | [customer-support](https://github.com/axisvela/praxo-core/tree/main/language/typescript/Tutorial/customer-support), [order-review](https://github.com/axisvela/praxo-core/tree/main/language/typescript/Tutorial/order-review), [travel-booking](https://github.com/axisvela/praxo-core/tree/main/language/typescript/Tutorial/travel-booking) | 13 | 1 | 2 |
| [v](https://github.com/axisvela/praxo-core/tree/main/language/v) | - | 13 | 1 | 1 |
| [zig](https://github.com/axisvela/praxo-core/tree/main/language/zig) | [gateway-health](https://github.com/axisvela/praxo-core/tree/main/language/zig/Tutorial/gateway-health) | 13 | 1 | 1 |

缺少应用教程的语言不等于缺少 Core；候选分配与实现验证分开。PowerShell 共享 C#；Sample/Bridge 不新增独立 Core。

## 按能力

| 能力 / Capability | 应用教程 / Application Paths |
| --- | --- |
| analysis | [fortran/simulation-metrics](https://github.com/axisvela/praxo-core/tree/main/language/fortran/Tutorial/simulation-metrics), [julia/experiment-comparison](https://github.com/axisvela/praxo-core/tree/main/language/julia/Tutorial/experiment-comparison), [matlab/signal-trends](https://github.com/axisvela/praxo-core/tree/main/language/matlab/Tutorial/signal-trends), [octave/signal-trends](https://github.com/axisvela/praxo-core/tree/main/language/octave/Tutorial/signal-trends), [perl/log-triage](https://github.com/axisvela/praxo-core/tree/main/language/perl/Tutorial/log-triage), [python/insurance-claims](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/insurance-claims), [r/data-quality](https://github.com/axisvela/praxo-core/tree/main/language/r/Tutorial/data-quality), [r/marketing-segmentation](https://github.com/axisvela/praxo-core/tree/main/language/r/Tutorial/marketing-segmentation), [r/wealth-analysis](https://github.com/axisvela/praxo-core/tree/main/language/r/Tutorial/wealth-analysis), [ruby/finops-review](https://github.com/axisvela/praxo-core/tree/main/language/ruby/Tutorial/finops-review) |
| approval | [python/legal-compliance](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/legal-compliance) |
| batch | [cobol/batch-exception-review](https://github.com/axisvela/praxo-core/tree/main/language/cobol/Tutorial/batch-exception-review) |
| checkpoint | [go/logistics-checkpoint](https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial/logistics-checkpoint) |
| citations | [python/education-tutoring](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/education-tutoring), [python/legal-compliance](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/legal-compliance), [python/office-qa](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/office-qa), [typescript/customer-support](https://github.com/axisvela/praxo-core/tree/main/language/typescript/Tutorial/customer-support) |
| draft | [c/device-diagnostics](https://github.com/axisvela/praxo-core/tree/main/language/c/Tutorial/device-diagnostics), [cpp/industrial-edge](https://github.com/axisvela/praxo-core/tree/main/language/cpp/Tutorial/industrial-edge), [csharp/healthcare-scheduling](https://github.com/axisvela/praxo-core/tree/main/language/csharp/Tutorial/healthcare-scheduling), [csharp/sales-crm](https://github.com/axisvela/praxo-core/tree/main/language/csharp/Tutorial/sales-crm), [fortran/simulation-metrics](https://github.com/axisvela/praxo-core/tree/main/language/fortran/Tutorial/simulation-metrics), [go/evidence-vault](https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial/evidence-vault), [go/incident-coordination](https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial/incident-coordination), [go/logistics-checkpoint](https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial/logistics-checkpoint), [go/soc-alert-triage](https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial/soc-alert-triage), [java/wealth-service](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/wealth-service), [lua/host-embedding](https://github.com/axisvela/praxo-core/tree/main/language/lua/Tutorial/host-embedding), [python/education-tutoring](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/education-tutoring), [python/insurance-claims](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/insurance-claims), [r/marketing-segmentation](https://github.com/axisvela/praxo-core/tree/main/language/r/Tutorial/marketing-segmentation), [r/wealth-analysis](https://github.com/axisvela/praxo-core/tree/main/language/r/Tutorial/wealth-analysis), [ruby/finops-review](https://github.com/axisvela/praxo-core/tree/main/language/ruby/Tutorial/finops-review), [rust/iot-gateway](https://github.com/axisvela/praxo-core/tree/main/language/rust/Tutorial/iot-gateway), [typescript/travel-booking](https://github.com/axisvela/praxo-core/tree/main/language/typescript/Tutorial/travel-booking), [zig/gateway-health](https://github.com/axisvela/praxo-core/tree/main/language/zig/Tutorial/gateway-health) |
| events | [go/incident-coordination](https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial/incident-coordination), [go/soc-alert-triage](https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial/soc-alert-triage) |
| filesystem | [go/evidence-vault](https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial/evidence-vault) |
| host | [c/device-diagnostics](https://github.com/axisvela/praxo-core/tree/main/language/c/Tutorial/device-diagnostics), [cpp/industrial-edge](https://github.com/axisvela/praxo-core/tree/main/language/cpp/Tutorial/industrial-edge), [lua/host-embedding](https://github.com/axisvela/praxo-core/tree/main/language/lua/Tutorial/host-embedding), [powershell/windows-diagnostics](https://github.com/axisvela/praxo-core/tree/main/language/powershell/Tutorial/windows-diagnostics), [rust/iot-gateway](https://github.com/axisvela/praxo-core/tree/main/language/rust/Tutorial/iot-gateway), [zig/gateway-health](https://github.com/axisvela/praxo-core/tree/main/language/zig/Tutorial/gateway-health) |
| http | [csharp/order-review](https://github.com/axisvela/praxo-core/tree/main/language/csharp/Tutorial/order-review), [csharp/sales-crm](https://github.com/axisvela/praxo-core/tree/main/language/csharp/Tutorial/sales-crm), [java/order-review](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/order-review), [java/wealth-service](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/wealth-service), [python/order-review](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/order-review), [typescript/customer-support](https://github.com/axisvela/praxo-core/tree/main/language/typescript/Tutorial/customer-support), [typescript/order-review](https://github.com/axisvela/praxo-core/tree/main/language/typescript/Tutorial/order-review) |
| pii | [go/soc-alert-triage](https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial/soc-alert-triage) |
| policy | [c/device-diagnostics](https://github.com/axisvela/praxo-core/tree/main/language/c/Tutorial/device-diagnostics), [cobol/batch-exception-review](https://github.com/axisvela/praxo-core/tree/main/language/cobol/Tutorial/batch-exception-review), [cpp/industrial-edge](https://github.com/axisvela/praxo-core/tree/main/language/cpp/Tutorial/industrial-edge), [csharp/healthcare-scheduling](https://github.com/axisvela/praxo-core/tree/main/language/csharp/Tutorial/healthcare-scheduling), [csharp/order-review](https://github.com/axisvela/praxo-core/tree/main/language/csharp/Tutorial/order-review), [csharp/sales-crm](https://github.com/axisvela/praxo-core/tree/main/language/csharp/Tutorial/sales-crm), [fortran/simulation-metrics](https://github.com/axisvela/praxo-core/tree/main/language/fortran/Tutorial/simulation-metrics), [go/evidence-vault](https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial/evidence-vault), [go/incident-coordination](https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial/incident-coordination), [go/logistics-checkpoint](https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial/logistics-checkpoint), [go/soc-alert-triage](https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial/soc-alert-triage), [java/order-review](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/order-review), [java/wealth-service](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/wealth-service), [julia/experiment-comparison](https://github.com/axisvela/praxo-core/tree/main/language/julia/Tutorial/experiment-comparison), [lua/host-embedding](https://github.com/axisvela/praxo-core/tree/main/language/lua/Tutorial/host-embedding), [matlab/signal-trends](https://github.com/axisvela/praxo-core/tree/main/language/matlab/Tutorial/signal-trends), [octave/signal-trends](https://github.com/axisvela/praxo-core/tree/main/language/octave/Tutorial/signal-trends), [perl/log-triage](https://github.com/axisvela/praxo-core/tree/main/language/perl/Tutorial/log-triage), [powershell/windows-diagnostics](https://github.com/axisvela/praxo-core/tree/main/language/powershell/Tutorial/windows-diagnostics), [python/education-tutoring](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/education-tutoring), [python/insurance-claims](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/insurance-claims), [python/legal-compliance](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/legal-compliance), [python/office-qa](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/office-qa), [python/order-review](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/order-review), [r/data-quality](https://github.com/axisvela/praxo-core/tree/main/language/r/Tutorial/data-quality), [r/marketing-segmentation](https://github.com/axisvela/praxo-core/tree/main/language/r/Tutorial/marketing-segmentation), [r/wealth-analysis](https://github.com/axisvela/praxo-core/tree/main/language/r/Tutorial/wealth-analysis), [ruby/finops-review](https://github.com/axisvela/praxo-core/tree/main/language/ruby/Tutorial/finops-review), [rust/iot-gateway](https://github.com/axisvela/praxo-core/tree/main/language/rust/Tutorial/iot-gateway), [typescript/customer-support](https://github.com/axisvela/praxo-core/tree/main/language/typescript/Tutorial/customer-support), [typescript/order-review](https://github.com/axisvela/praxo-core/tree/main/language/typescript/Tutorial/order-review), [typescript/travel-booking](https://github.com/axisvela/praxo-core/tree/main/language/typescript/Tutorial/travel-booking), [zig/gateway-health](https://github.com/axisvela/praxo-core/tree/main/language/zig/Tutorial/gateway-health) |
| retrieval | [python/education-tutoring](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/education-tutoring), [python/office-qa](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/office-qa) |
| streaming | [typescript/customer-support](https://github.com/axisvela/praxo-core/tree/main/language/typescript/Tutorial/customer-support) |
| structured-output | [python/insurance-claims](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/insurance-claims) |
| tools | [c/device-diagnostics](https://github.com/axisvela/praxo-core/tree/main/language/c/Tutorial/device-diagnostics), [cobol/batch-exception-review](https://github.com/axisvela/praxo-core/tree/main/language/cobol/Tutorial/batch-exception-review), [cpp/industrial-edge](https://github.com/axisvela/praxo-core/tree/main/language/cpp/Tutorial/industrial-edge), [csharp/healthcare-scheduling](https://github.com/axisvela/praxo-core/tree/main/language/csharp/Tutorial/healthcare-scheduling), [csharp/order-review](https://github.com/axisvela/praxo-core/tree/main/language/csharp/Tutorial/order-review), [csharp/sales-crm](https://github.com/axisvela/praxo-core/tree/main/language/csharp/Tutorial/sales-crm), [fortran/simulation-metrics](https://github.com/axisvela/praxo-core/tree/main/language/fortran/Tutorial/simulation-metrics), [go/evidence-vault](https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial/evidence-vault), [go/incident-coordination](https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial/incident-coordination), [go/logistics-checkpoint](https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial/logistics-checkpoint), [go/soc-alert-triage](https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial/soc-alert-triage), [java/order-review](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/order-review), [java/wealth-service](https://github.com/axisvela/praxo-core/tree/main/language/java/Tutorial/wealth-service), [julia/experiment-comparison](https://github.com/axisvela/praxo-core/tree/main/language/julia/Tutorial/experiment-comparison), [lua/host-embedding](https://github.com/axisvela/praxo-core/tree/main/language/lua/Tutorial/host-embedding), [matlab/signal-trends](https://github.com/axisvela/praxo-core/tree/main/language/matlab/Tutorial/signal-trends), [octave/signal-trends](https://github.com/axisvela/praxo-core/tree/main/language/octave/Tutorial/signal-trends), [perl/log-triage](https://github.com/axisvela/praxo-core/tree/main/language/perl/Tutorial/log-triage), [powershell/windows-diagnostics](https://github.com/axisvela/praxo-core/tree/main/language/powershell/Tutorial/windows-diagnostics), [python/education-tutoring](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/education-tutoring), [python/insurance-claims](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/insurance-claims), [python/legal-compliance](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/legal-compliance), [python/order-review](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/order-review), [r/data-quality](https://github.com/axisvela/praxo-core/tree/main/language/r/Tutorial/data-quality), [r/marketing-segmentation](https://github.com/axisvela/praxo-core/tree/main/language/r/Tutorial/marketing-segmentation), [r/wealth-analysis](https://github.com/axisvela/praxo-core/tree/main/language/r/Tutorial/wealth-analysis), [ruby/finops-review](https://github.com/axisvela/praxo-core/tree/main/language/ruby/Tutorial/finops-review), [rust/iot-gateway](https://github.com/axisvela/praxo-core/tree/main/language/rust/Tutorial/iot-gateway), [typescript/order-review](https://github.com/axisvela/praxo-core/tree/main/language/typescript/Tutorial/order-review), [typescript/travel-booking](https://github.com/axisvela/praxo-core/tree/main/language/typescript/Tutorial/travel-booking), [zig/gateway-health](https://github.com/axisvela/praxo-core/tree/main/language/zig/Tutorial/gateway-health) |

## 基础与进阶示例

这些跨行业条目复用原来的 examples/recipes 路径，不重命名为新的行业场景。

| 主题 / Theme | 语言条目 / Language Entries | 入口 / Entry |
| --- | ---: | --- |
| consumer | 31 | [Language Coverage](language-coverage.md) |
| live-model | 31 | [Language Coverage](language-coverage.md) |
| checkpoint | 31 | [Language Coverage](language-coverage.md) |
| event-sink | 31 | [Language Coverage](language-coverage.md) |
| retry | 31 | [Language Coverage](language-coverage.md) |
| provider-fallback | 31 | [Language Coverage](language-coverage.md) |
| streaming | 31 | [Language Coverage](language-coverage.md) |
| structured-output | 31 | [Language Coverage](language-coverage.md) |
| identity-policy | 31 | [Language Coverage](language-coverage.md) |
| service | 31 | [Language Coverage](language-coverage.md) |
| mcp | 31 | [Language Coverage](language-coverage.md) |
| hitl | 31 | [Language Coverage](language-coverage.md) |
| session-checkpoint | 31 | [Language Coverage](language-coverage.md) |
| advanced-delegation | 27 | [Language Coverage](language-coverage.md) |
| advanced-long-running | 1 | [Language Coverage](language-coverage.md) |
| advanced-workspace | 1 | [Language Coverage](language-coverage.md) |

### 其他示例与 Recipes

| 主题 / Theme | 源码入口 / Source Entries |
| --- | --- |
| batch-exception-review | [cobol](https://github.com/axisvela/praxo-core/tree/main/language/cobol/examples/batch-exception-review) |
| checkpoint | [go](https://github.com/axisvela/praxo-core/tree/main/examples/checkpoint) |
| conformance-go | [go](https://github.com/axisvela/praxo-core/tree/main/examples/recipes/conformance-go) |
| context-budget-go | [go](https://github.com/axisvela/praxo-core/tree/main/examples/recipes/context-budget-go) |
| ecosystem | [go](https://github.com/axisvela/praxo-core/tree/main/examples/ecosystem) |
| ecosystem-sdk | [go](https://github.com/axisvela/praxo-core/tree/main/examples/ecosystem-sdk) |
| embedded-service-auth | [go](https://github.com/axisvela/praxo-core/tree/main/examples/embedded-service-auth) |
| multi-agent-go | [go](https://github.com/axisvela/praxo-core/tree/main/examples/recipes/multi-agent-go) |
| plugin | [go](https://github.com/axisvela/praxo-core/tree/main/examples/plugin) |
| plugin-lifecycle-go | [go](https://github.com/axisvela/praxo-core/tree/main/examples/recipes/plugin-lifecycle-go) |
| reference | [go](https://github.com/axisvela/praxo-core/tree/main/examples/reference) |
| representative-chain | [d](https://github.com/axisvela/praxo-core/tree/main/language/d/examples/representative-chain), [dart](https://github.com/axisvela/praxo-core/tree/main/language/dart/examples/representative-chain), [delphi](https://github.com/axisvela/praxo-core/tree/main/language/delphi/examples/representative-chain), [elixir](https://github.com/axisvela/praxo-core/tree/main/language/elixir/examples/representative-chain), [erlang](https://github.com/axisvela/praxo-core/tree/main/language/erlang/examples/representative-chain), [go](https://github.com/axisvela/praxo-core/tree/main/examples/representative-chain), [haskell](https://github.com/axisvela/praxo-core/tree/main/language/haskell/examples/representative-chain), [julia](https://github.com/axisvela/praxo-core/tree/main/language/julia/examples/representative-chain), [lua](https://github.com/axisvela/praxo-core/tree/main/language/lua/examples/representative-chain), [matlab](https://github.com/axisvela/praxo-core/tree/main/language/matlab/examples/representative-chain), [nim](https://github.com/axisvela/praxo-core/tree/main/language/nim/examples/representative-chain), [objc](https://github.com/axisvela/praxo-core/tree/main/language/objc/examples/representative-chain), [ocaml](https://github.com/axisvela/praxo-core/tree/main/language/ocaml/examples/representative-chain), [octave](https://github.com/axisvela/praxo-core/tree/main/language/octave/examples/representative-chain), [perl](https://github.com/axisvela/praxo-core/tree/main/language/perl/examples/representative-chain), [php](https://github.com/axisvela/praxo-core/tree/main/language/php/examples/representative-chain), [powershell](https://github.com/axisvela/praxo-core/tree/main/language/powershell/examples/representative-chain), [python](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/representative-chain), [r](https://github.com/axisvela/praxo-core/tree/main/language/r/examples/representative-chain), [ruby](https://github.com/axisvela/praxo-core/tree/main/language/ruby/examples/representative-chain), [rust](https://github.com/axisvela/praxo-core/tree/main/language/rust/examples/representative-chain), [swift](https://github.com/axisvela/praxo-core/tree/main/language/swift/examples/representative-chain), [typescript](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples/representative-chain), [v](https://github.com/axisvela/praxo-core/tree/main/language/v/examples/representative-chain), [zig](https://github.com/axisvela/praxo-core/tree/main/language/zig/examples/representative-chain) |
| sandbox | [go](https://github.com/axisvela/praxo-core/tree/main/examples/sandbox) |
| service-auth | [python](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/service-auth), [typescript](https://github.com/axisvela/praxo-core/tree/main/language/typescript/examples/service-auth) |
| structured-output-app | [python](https://github.com/axisvela/praxo-core/tree/main/language/python/examples/structured-output-app) |
| vfs-containment-go | [go](https://github.com/axisvela/praxo-core/tree/main/examples/recipes/vfs-containment-go) |
| workspace-agent | [go](https://github.com/axisvela/praxo-core/tree/main/examples/workspace-agent) |

| 指南 / Guide | 范围 / Scope |
| --- | --- |
| [Build a Read-Only Workspace Agent](https://github.com/axisvela/praxo-core/tree/main/docs/guides/workspace-agent-tutorial.md) | filesystem,tools,policy |
| [Python Structured Output Application](https://github.com/axisvela/praxo-core/tree/main/docs/guides/python-structured-output-app.md) | structured-output,batch,checkpoint |
| [Representative End-to-End Chain Tutorial](https://github.com/axisvela/praxo-core/tree/main/docs/guides/representative-chain-tutorial.md) | delegation,mcp,events,policy |
| [MCP Client by Language](https://github.com/axisvela/praxo-core/tree/main/docs/guides/mcp-tutorial.md) | mcp,tools |
| [Structured Output by Language](https://github.com/axisvela/praxo-core/tree/main/docs/guides/structured-output-tutorial.md) | structured-output |
| [Embed Core in an HTTP Service](https://github.com/axisvela/praxo-core/tree/main/docs/guides/embedded-service-tutorial.md) | http,policy |

## 维护与导出

```bash
python scripts/tutorial_catalog.py
python scripts/tutorial_catalog.py --check
python scripts/tutorial_catalog.py --json
python scripts/test_tutorial_catalog.py
```

JSON 包含逐条语言/机制源码路径，供筛选和统计。规划、源码存在、本地运行、CI、实网与独立采用必须保持不同证据层级。
