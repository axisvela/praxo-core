# 100 个智能体场景

这 100 个目标合并了两批各 50 个候选场景，不是教程全集。原有应用、主题、指南和跨语言示例统一见
[教程与场景总目录](tutorial-catalog.md)，支持行业、语言、能力分类并明确计数口径。

本目录把十六大领域、100 个应用目标纳入 [Tutorial 整体规划](tutorial-plan.md)。
**100 个完整场景均为候选，不代表已有完整应用。** 已有教程只是相关的狭窄教学切片，
其运行证据与限制仍以规划状态表为准。语言分配是候选实现目标，不是新增维护责任、
排期或支持承诺。英文同路径页面列出每个场景的已有源码入口。

状态分为三层：**候选目标**是待实现的完整成果；**已有相关切片**只是可复用的局部机制或
教学路径；**完整实现**须有该场景全部验收的记录，不能由切片推导。
当前完整实现为 **0/100**。前八领域编号保持不变，新增八领域逐条列出切片与完整实现状态。

## 闭环要求

每个实现应展示有界规划、应用自有状态、工具结果以及基于结果的后续决策。
单次脚本工具调用只能算机制演示，不能算自主端到端完成任务。
规划可使用确定性模式以便复现；记忆、观察与历史工具结果仍是不可信数据，不能提升成
system 指令。Memory Store 不等于自动召回；checkpoint 消息续跑不等于崩溃步骤恢复、
效果账本或 exactly-once。状态按消费者、租户与运行隔离，审批编辑后重授权最终参数，
并明确工具范围、调用预算与取消边界。

## 软件工程与 IT 运维（8）

以下均为候选。目标语言不表示该语言已完成这个场景。

| ID | 场景 | 目标语言 | 首个有界教学成果 / 相关切片 |
| --- | --- | --- | --- |
| SE-01 | 端到端全栈代码开发 | TypeScript、Go、Dart | 规划微型应用、在允许的临时工作区修改并构建；不部署 |
| SE-02 | 自动化 Bug 定位与修复 | Python、Rust、Perl | 复现预置缺陷、草拟补丁、重跑测试；PR 创建单独授权 |
| SE-03 | 遗留代码重构与迁移 | COBOL、Java、Delphi | 依赖清单与迁移草案，保持 fixture 输出不变；不迁移生产系统 |
| SE-04 | 单元测试与压测生成 | Java、C#、Haskell | 对本地 fixture 生成有界测试；压测仅允许的 loopback 服务 |
| SE-05 | 代码审查、安全与许可证审计 | Rust、OCaml、Go | 审查固定 diff 与依赖清单，引用发现并标注不确定性；证据库仅是 containment 切片 |
| SE-06 | AIOps 自愈与 RCA | Go、Elixir、Erlang | 关联 fixture 事件并草拟需审批的回滚；现有 incident 教程仅读取与草案 |
| SE-07 | 云资源与 FinOps 治理 | Ruby、PowerShell、D | [Ruby 成本复核切片](https://github.com/axisvela/praxo-core/tree/main/language/ruby/Tutorial/finops-review)计算闲置成本并草拟复核；不修改云资源、不使用真实凭据；其余语言为候选 |
| SE-08 | API 编排与异构集成 | PHP、Java、TypeScript | 映射两个合成 API、校验 schema、处理未知结果；不访问任意 URL；[PHP API 编排切片](https://github.com/axisvela/praxo-core/tree/main/language/php/Tutorial/api-orchestration)覆盖两个 fixture API 与复核草案 |

## 企业运营与办公（7）

| ID | 场景 | 目标语言 | 首个有界教学成果 / 相关切片 |
| --- | --- | --- | --- |
| OP-01 | IT 与 HR 内部服务台 | C#、PHP、PowerShell | 限定员工请求并草拟审批；现有订单服务台不授予员工权限 |
| OP-02 | 会议全生命周期管理 | Dart、Swift、TypeScript | 对齐固定日历、草拟纪要与任务；发送邀请前审批；[Dart 会议协调切片](https://github.com/axisvela/praxo-core/tree/main/language/dart/Tutorial/meeting-coordination)覆盖日历证据与纪要草案 |
| OP-03 | 企业知识库动态维护 | Python、Elixir、OCaml | 检测文档 fixture 变更、去重并草拟带引用修订；不自动写 Wiki |
| OP-04 | 跨系统 Agentic RPA | Java、C#、Delphi | 对账合成报销/采购记录；未知效果时停止盲重试 |
| OP-05 | 招聘与人才匹配 | Ruby、PHP、Python | 对合成人才做岗位相关技能匹配并解释；不自动招聘决策或联系 |
| OP-06 | 个性化入职导师 | Python、Dart、Swift | 按角色与前置条件规划课程；权限仍归应用 |
| OP-07 | 高管经营简报 | R、Julia、D | 计算合成经营变化并引用指标；不把相关性当因果；[D 高管简报切片](https://github.com/axisvela/praxo-core/tree/main/language/d/Tutorial/executive-brief)覆盖固定变化与复核草案 |

## 客服、营销与销售（7）

| ID | 场景 | 目标语言 | 首个有界教学成果 / 相关切片 |
| --- | --- | --- | --- |
| CS-01 | 多模态全渠道客服 | TypeScript、C#、PHP | 基于受限订单证据草拟处理方案；现有客服为文本/SSE，不是退款或多模态验证 |
| CS-02 | B2B 潜客与线索培育 | Ruby、PHP、Elixir | 合成企业画像排序与许可触达草案；不爬取或发送垃圾信息 |
| CS-03 | 销售通话辅助与复盘 | C#、Swift、TypeScript | 从固定转录提取异议并草拟 CRM 更新；现有 CRM 教程仅跟进草案 |
| CS-04 | 内容营销与矩阵运营 | Python、R、Dart | 计算分群、草拟内容、发布审批；现有 R 分群不发送 |
| CS-05 | 电商定价与补货 | Java、PHP、Ruby | 模拟价格/库存约束、草拟补货单；不调整真实价格 |
| CS-06 | 流失预警与主动挽留 | R、Elixir、Julia | 计算固定风险信号、草拟基于同意的优惠；不推断敏感特征或自动触达 |
| CS-07 | 跨境多语言本地化 | TypeScript、PHP、Perl | 草拟本地化商品文本并引用固定规则；不保证法律/税务合规 |

## 金融、财税与合规（6）

| ID | 场景 | 目标语言 | 首个有界教学成果 / 相关切片 |
| --- | --- | --- | --- |
| FC-01 | 投研与财报分析 | R、Julia、Java | 对合成财报计算比率并列假设；现有组合分析不是投研验证 |
| FC-02 | 量化执行与风险控制 | C++、Rust、D | 回放固定价格、用确定性控制校验风险、草拟订单；不交易、不承诺毫秒执行 |
| FC-03 | 信贷尽调与反欺诈 | Java、COBOL、Python | 交叉核验合成记录并输出复核证据；不自动拒贷或判定欺诈 |
| FC-04 | 税务筹划与申报 | COBOL、Java、Delphi | 校验合成账本、按固定规则草拟申报；不真实申报、不提供税务建议 |
| FC-05 | 合同全生命周期审查 | Python、OCaml、C# | 比对固定条款和红线、建议修订；审批改动须最终重授权 |
| FC-06 | 监管追踪与内控审计 | Python、R、Perl | 比较版本化规则 fixture 并草拟整改；现有合规教程为脚本审批而非真实审核人 |

## 科研与前沿探索（6）

| ID | 场景 | 目标语言 | 首个有界教学成果 / 相关切片 |
| --- | --- | --- | --- |
| SC-01 | 文献综述与假设生成 | Python、Julia、Haskell | 检索固定摘要、引用主张、标明假设未验证；不编造论文；[Haskell 文献综述切片](https://github.com/axisvela/praxo-core/tree/main/language/haskell/Tutorial/literature-review)覆盖两篇 fixture 论文与未验证草案 |
| SC-02 | 制药与分子设计 | Python、Julia、C++ | 固定约束下排序合成描述符；不声称药效、毒性、合成或临床结果 |
| SC-03 | 自动化实验室 | Julia、Rust、C | 模拟参数/结果迭代且独立校验限制；不操作实验设备或化学品 |
| SC-04 | 材料逆向设计与仿真 | Fortran、Julia、C++ | 计算固定候选属性并草拟下轮仿真；不声称发现有效材料 |
| SC-05 | 气象建模与天气预警 | Fortran、R、Octave | 计算固定时序异常、草拟复核通知；不做业务预报或救灾调度 |
| SC-06 | 科研清洗与统计建模 | R、Julia、MATLAB | 校验固定数据与统计方法；现有 data-quality 为相关切片，原生 MATLAB 未验证 |

## 工业、供应链与能源（6）

| ID | 场景 | 目标语言 | 首个有界教学成果 / 相关切片 |
| --- | --- | --- | --- |
| IN-01 | 预测维护与检修排程 | C++、Rust、Nim | 计算固定传感指标并草拟维护；[工业边缘](https://github.com/axisvela/praxo-core/tree/main/language/cpp/Tutorial/industrial-edge)与 [Nim 维护分诊](https://github.com/axisvela/praxo-core/tree/main/language/nim/Tutorial/maintenance-triage)均不验证故障窗口预测 |
| IN-02 | 柔性产线动态排产 | Erlang、C++、V | 重排有界合成任务队列、草拟 MES/AGV 指令；不物理调度；[V 生产排产切片](https://github.com/axisvela/praxo-core/tree/main/language/v/Tutorial/production-scheduling)计算固定优先顺序与草案 |
| IN-03 | 供应链断链预警与寻源 | Go、Java、Ruby | 评估合成供应商事件并草拟替代；物流 checkpoint 仅消息续跑 |
| IN-04 | 微网调度与负荷平衡 | Julia、Fortran、Zig | 模拟有约束充放电计划，Agent 外校验安全限制；不发电网指令 |
| IN-05 | 图纸审查与 BOM | C++、C#、OCaml | 校验合成的已解析图纸图并草拟 BOM；不宣称 CAD/BIM 视觉或工程认证 |
| IN-06 | 精准灌溉与病虫害防治 | C、Lua、Nim | 评估固定土壤/天气观察并草拟有界灌溉请求；不控制无人机/执行器 |

## 医疗健康（5）

| ID | 场景 | 目标语言 | 首个有界教学成果 / 相关切片 |
| --- | --- | --- | --- |
| HC-01 | 临床辅助与 MDT | Python、Java、R | 引用合成指南片段、证据不足时弃答；不诊断或决定治疗 |
| HC-02 | 慢病管理与随访 | Swift、Dart、Objective-C | 汇总合成穿戴数据、交人工复核；不调整剂量或个体治疗 |
| HC-03 | 临床试验招募匹配 | Python、Java、C# | 判断合成入排条件、解释未知项；不搜索真实患者或决定入组 |
| HC-04 | 病历质控与 DRG/DIP 编码 | Java、COBOL、C# | 检查合成记录完整性并草拟代码；不优化骗保、不虚假编码、不提交账单 |
| HC-05 | 心理支持与 CBT 练习 | Swift、Dart、Python | 合成练习对话与明确的危机转人工分支；不替代治疗师或独立处理危机 |

## 个人、教育与具身（5）

| ID | 场景 | 目标语言 | 首个有界教学成果 / 相关切片 |
| --- | --- | --- | --- |
| PE-01 | 苏格拉底式学习导师 | Python、TypeScript、Haskell | 记录合成学习尝试并渐进提问；现有辅导教程是课程检索而非已验证自适应导师 |
| PE-02 | 差旅与生活全案管家 | TypeScript、Dart、Swift | 在固定预算下重排行程并草拟预订；现有 travel-booking 不支付或改签 |
| PE-03 | 数字信息与隐私代理 | Rust、Go、Objective-C | 分类固定消息、草拟删除/轮换请求；不使用真实密码、不访问账户或删除数据 |
| PE-04 | 人形机器人与家庭服务 | C++、Rust、Zig | 模拟观察/规划/动作、权限收窄、观测新鲜度和取消确认；无硬件或安全认证 |
| PE-05 | 游戏 NPC 与动态叙事 | Lua、C、V | 持久化合成角色状态、选择受限宿主动作、观察结果；无任意宿主命令 |

## 网络安全与攻防对抗（7）

测试须有明确授权，限定自有 fixture 或隔离实验环境。不提供任意目标发现、实网漏洞利用、
凭据窃取或自动反击能力。

| ID | 场景 | 目标语言 | 候选的有界教学成果 | 已有相关切片 | 完整实现 |
| --- | --- | --- | --- | --- | --- |
| CY-01 | 自动化渗透测试与红队演练 | Rust、Go、Python | 盘点允许的 loopback 实验资产并报告预置配置缺陷；不做公网扫描或攻击链 | 无 | 未实现 |
| CY-02 | SOC 告警研判与 SOAR 响应 | Go、Elixir、Erlang | 关联合成 EDR/防火墙事件并草拟隔离；不真实封禁 | [SOC 分诊](https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial/soc-alert-triage)：固定告警，不是真实 EDR 关联 | 未实现 |
| CY-03 | 威胁狩猎与 TTP 还原 | Perl、Rust、Python | 检索固定日志、引用合成 TTP 时间线；无外部情报或 APT 检测保证 | [日志巡检](https://github.com/axisvela/praxo-core/tree/main/language/perl/Tutorial/log-triage)：仅严重级别统计 | 未实现 |
| CY-04 | 钓鱼识别与反钓鱼演练 | Python、TypeScript、C# | 分类合成邮件并草拟获授权的安全培训；不发送欺骗邮件或攻击基础设施 | 无 | 未实现 |
| CY-05 | 零信任策略动态调优 | Java、C#、Go | 回放合成访问决策、建议收窄授权；不放宽真实权限 | 无 | 未实现 |
| CY-06 | DLP 与隐私脱敏 | Go、Rust、Objective-C | 对合成导出检查指定敏感字段，在共享前拒绝或脱敏；不保证加密或完整 DLP | [SOC 分诊](https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial/soc-alert-triage)：仅邮箱/电话脱敏 | 未实现 |
| CY-07 | 开源供应链投毒监测 | Rust、OCaml、Ruby | 比较固定清单与维护者变更 fixture，草拟版本锁定；非已验证恶意代码检测 | 无 | 未实现 |

## 智慧城市与公共治理（7）

| ID | 场景 | 目标语言 | 候选的有界教学成果 | 已有相关切片 | 完整实现 |
| --- | --- | --- | --- | --- | --- |
| CT-01 | 城市信号灯全域协同 | Erlang、C++、Julia | 模拟固定路口队列，在 Agent 外校验配时限制；不发信号灯指令 | 无 | 未实现 |
| CT-02 | 生命线管网泄漏定位与调度 | Fortran、Rust、Nim | 排序合成压力异常并草拟巡检；不隔离阀门或调度现场作业 | [信号趋势](https://github.com/axisvela/praxo-core/tree/main/language/octave/Tutorial/signal-trends)：仅指标，不定位泄漏 | 未实现 |
| CT-03 | 政务跨部门审批 | Java、C#、PHP | 校验合成材料并草拟并联审核任务；不做真实身份核验或行政审批 | 无 | 未实现 |
| CT-04 | 应急指挥与资源调度 | Go、Julia、Erlang | 模拟断路与有约束救援路线；不提供业务救援指令或真实调度 | 无 | 未实现 |
| CT-05 | 污染溯源与执法辅助 | R、Fortran、Python | 比较合成监测/天气记录并草拟调查假设；不认定因果或违法 | 无 | 未实现 |
| CT-06 | 垃圾分类与清运优化 | Julia、Dart、V | 按车辆约束重排有界合成清运队列；不发车辆指令 | 无 | 未实现 |
| CT-07 | 公共预算执行与绩效 | R、COBOL、Java | 对账合成拨款与里程碑，解释异常；不出具正式审计结论 | 无 | 未实现 |

## 交通物流、航运与低空经济（7）

| ID | 场景 | 目标语言 | 候选的有界教学成果 | 已有相关切片 | 完整实现 |
| --- | --- | --- | --- | --- | --- |
| TL-01 | 无人机集群巡检与空域消冲 | Rust、C++、Zig | 模拟有界航点，Agent 外检查冲突；不飞行或下发避障指令 | 无 | 未实现 |
| TL-02 | 集装箱堆场与岸桥协同 | Erlang、C++、Java | 按资源约束重排合成装卸任务；不调度岸桥或 AGV | 无 | 未实现 |
| TL-03 | 远洋气象导航与燃油优化 | Fortran、Julia、C++ | 比较合成航线/气象成本并草拟路线；无导航、节油或 CII 合规保证 | 无 | 未实现 |
| TL-04 | 冷链温控与货损预警 | Rust、Nim、Octave | 计算固定温度越界并草拟转运复核；不调整制冷或保证医药货物安全 | [信号趋势](https://github.com/axisvela/praxo-core/tree/main/language/octave/Tutorial/signal-trends)：仅通用信号 fixture | 未实现 |
| TL-05 | 多式联运报关与路径重算 | Java、Go、PHP | 校验合成单证并比较替代路线；不报关 | [物流 checkpoint](https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial/logistics-checkpoint)：仅消息续跑与草案 | 未实现 |
| TL-06 | 自动驾驶远程脱困与地图更新 | C++、Rust、D | 回放合成道路拓扑变更、草拟地图补丁；不接管车辆 | 无 | 未实现 |
| TL-07 | 机场机位与延误恢复 | Java、Julia、C# | 模拟机位/机组/衔接约束并草拟方案；无业务调度或时延保证 | [旅行预订](https://github.com/axisvela/praxo-core/tree/main/language/typescript/Tutorial/travel-booking)：占座 fixture，不是机场恢复 | 未实现 |

## 传媒、设计、游戏与数字内容（7）

| ID | 场景 | 目标语言 | 候选的有界教学成果 | 已有相关切片 | 完整实现 |
| --- | --- | --- | --- | --- | --- |
| MD-01 | 影视分镜与虚拟制片预演 | Lua、C++、TypeScript | 把固定剧本转为有界镜头计划草案；无已验证 Unreal 集成或渲染制作 | 无 | 未实现 |
| MD-02 | 新闻事实核查与多源验证 | Python、Haskell、Perl | 比较固定来源与元数据、引用矛盾与不确定性；无真伪保证或实网抓取 | [办公问答](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/office-qa)：仅引用机制 | 未实现 |
| MD-03 | 开放世界游戏生态演化 | Lua、C、V | 用持久化合成状态模拟经济/资源规则；不保证规模或长期平衡 | [宿主嵌入](https://github.com/axisvela/praxo-core/tree/main/language/lua/Tutorial/host-embedding)：设备回调，不是游戏生态 | 未实现 |
| MD-04 | 配音、口型同步与文化本地化 | Python、Swift、C++ | 为合成/获许可素材规划字幕与时序；无冒充、未经同意的声音克隆或已验证口型同步 | 无 | 未实现 |
| MD-05 | 工业设计与 3D 拓扑生成 | C++、Julia、Fortran | 按已述约束比较合成网格描述符；无可制造性或力学认证 | 无 | 未实现 |
| MD-06 | 有声书与沉浸广播剧制作 | Python、Dart、Swift | 规划获许可角色声音与固定混音提示；无合成成品或权利保证 | 无 | 未实现 |
| MD-07 | 数字人直播互动场控 | TypeScript、Elixir、Lua | 回放合成互动事件并草拟讲解顺序；不做受众画像、发券或真实直播控制 | 无 | 未实现 |

## 法律、司法与知识产权（5）

| ID | 场景 | 目标语言 | 候选的有界教学成果 | 已有相关切片 | 完整实现 |
| --- | --- | --- | --- | --- | --- |
| LJ-01 | 诉讼证据链与质证提纲 | Python、OCaml、Go | 从合成文档建立带引用时间线、标记矛盾；非法律意见或证据可采性证明 | [证据库](https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial/evidence-vault)：受限读取，不是诉讼分析 | 未实现 |
| LJ-02 | 专利检索、FTO 与布局 | Python、Java、Haskell | 比较合成权利要求并草拟律师复核问题；非全面专利检索或不侵权意见 | 无 | 未实现 |
| LJ-03 | 商业尽职调查 | Java、C#、Ruby | 对账合成股权/合同/纠纷并草拟清单；无已验证并购结论 | 无 | 未实现 |
| LJ-04 | 类案检索与法律文书草拟 | Python、Java、OCaml | 检索固定合成案例、草拟带引用提纲；非量刑建议或司法裁判 | [法律合规](https://github.com/axisvela/praxo-core/tree/main/language/python/Tutorial/legal-compliance)：仅政策引用和脚本审批门 | 未实现 |
| LJ-05 | 数字版权监测与维权流程 | Rust、PHP、TypeScript | 比较获授权 fixture 素材、草拟证据包；不全网扫描、自动发 DMCA 或裁定侵权 | 无 | 未实现 |

## 建筑工程、矿业与空间运营（5）

| ID | 场景 | 目标语言 | 候选的有界教学成果 | 已有相关切片 | 完整实现 |
| --- | --- | --- | --- | --- | --- |
| BE-01 | 工地安全巡检与整改复核 | C++、Rust、C# | 评估合成巡检标签、跟踪复核清单；无真实视觉或安全认证结论 | 无 | 未实现 |
| BE-02 | 商业楼宇 HVAC 与照明节能 | Julia、C、Delphi | 模拟人流/热工约束并草拟设置；无 BMS 指令或节能证明 | 无 | 未实现 |
| BE-03 | 智慧矿山与边坡风险预警 | Fortran、Rust、C++ | 计算合成位移指标、草拟复核警报；无塌方预测或矿车调度 | 无 | 未实现 |
| BE-04 | 招投标编制与串标审查 | Java、PHP、COBOL | 校验合成资质、标记文档相似性；不自动投标或认定串标 | 无 | 未实现 |
| BE-05 | 地产选址与租金预测 | R、Julia、D | 比较合成选址指标、披露预测假设；无概率/回报验证或个人位置画像 | 无 | 未实现 |

## 农业、林业与生态保护（5）

| ID | 场景 | 目标语言 | 候选的有界教学成果 | 已有相关切片 | 完整实现 |
| --- | --- | --- | --- | --- | --- |
| AE-01 | 畜牧健康监测与精准饲喂 | C、Nim、Rust | 汇总合成个体观察并草拟复核请求；不兽医诊断、隔离或饲喂控制 | 无 | 未实现 |
| AE-02 | 森林火险与蔓延推演 | Fortran、Julia、R | 回放合成天气/燃料网格、比较模型传播；无业务预警或防火带调度 | 无 | 未实现 |
| AE-03 | 海洋牧场水质与投饵 | Lua、C、Octave | 计算固定溶氧/温度指标、草拟有界动作；不控制增氧机或投饵机 | [宿主嵌入](https://github.com/axisvela/praxo-core/tree/main/language/lua/Tutorial/host-embedding)：仅宿主回调机制 | 未实现 |
| AE-04 | 农产品套保与产销规划 | R、Julia、COBOL | 模拟风险敞口并比较情景成本；不发期货订单、不锁价、不提供金融建议 | 无 | 未实现 |
| AE-05 | 生物多样性与盗猎预警 | Python、Rust、Zig | 分类合成标注观察、草拟护林员复核；无物种识别保证或自动追捕 | 无 | 未实现 |

## 组织治理、架构与跨学科协同（7）

| ID | 场景 | 目标语言 | 候选的有界教学成果 | 已有相关切片 | 完整实现 |
| --- | --- | --- | --- | --- | --- |
| OG-01 | EA 资产图谱治理 | Java、OCaml、C# | 按标准比较固定应用/API 图并草拟变更发现；无生产扫描或自动拦截 | 无 | 未实现 |
| OG-02 | 多智能体社会与政策沙盘 | Julia、Erlang、Haskell | 模拟小型有界合成人群并报告敏感性；无数万规模或真实政策预测 | 无 | 未实现 |
| OG-03 | 跨文化谈判同传与策略辅助 | TypeScript、Swift、Python | 比较固定转录与术语、标记不确定性；无微表情推断、读心或实时同传保证 | 无 | 未实现 |
| OG-04 | 开源社区治理与贡献者体验 | Ruby、Elixir、Perl | 分类合成 Issue、草拟贡献指导与评审请求；不自动关闭问题或冒充维护者 | 无 | 未实现 |
| OG-05 | EDA 布局布线优化 | C++、Fortran、Julia | 探索合成布局网格、报告已述 PPA 代理指标；无代工厂有效版图或优化证明 | 无 | 未实现 |
| OG-06 | 个人数字孪生与跨应用记忆 | Swift、Objective-C、Dart | 存储合成的同意范围内记忆、记录来源并测试删除；无真实邮箱/密码或无限召回 | [物流 checkpoint](https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial/logistics-checkpoint)：仅消息续跑，不是个人记忆中枢 | 未实现 |
| OG-07 | 多学科 Virtual PI | Python、Julia、Haskell | 协调有界文献/仿真/复核任务，限制共享预算并标注来源；不保证自主科研有效性 | [代表性链路](https://github.com/axisvela/praxo-core/tree/main/examples/representative-chain)：应用级委派，不是科研团队 | 未实现 |

## 全 Core 语言分配

这是**规划覆盖**，不是 100 个场景乘以 31 种语言的实现承诺。优先每语言一个差异化闭环，
复用教学数据与验收，不复制 agent loop，也不让所有语言调用同一个远程 Agent 冒充原生实现。

| Core 目录 | 候选场景 | 运行时与证据边界 |
| --- | --- | --- |
| `go` | SE-01, SE-06, IN-03, PE-03 | 参考 Core；存储与效果归应用 |
| `python` | SE-02, SC-01, HC-01, PE-01 | 原生 Core；检索与分析工具保持受限 |
| `typescript` | SE-01, CS-01, PE-02 | 原生 Core；浏览器 UI 不是新增 Core |
| `java` | SE-03, OP-04, HC-03 | 原生 Core；Windows 本地限制与 CI 分开 |
| `rust` | SE-02, FC-02, PE-04 | 原生 Core；不保证实时控制 |
| `csharp` | OP-01, HC-03, IN-05 | 原生 .NET Core；身份归应用 |
| `r` | OP-07, FC-01, SC-06 | 原生 Core；统计计算不是因果证明 |
| `c` | SC-03, IN-06, PE-05 | 原生 Core；内存/传输/宿主限制由调用方负责 |
| `cpp` | FC-02, IN-01, PE-04 | 原生 Core；设备 SDK 与安全控制器在外部 |
| `fortran` | SC-04, SC-05, IN-04 | 原生 Core；固定计算，不执行任意生成代码 |
| `cobol` | SE-03, FC-04, HC-04 | 原生 Core；GnuCOBOL 不代表 z/OS/CICS/IMS |
| `php` | SE-08, OP-01, CS-05 | 原生 Core；传输与发布包状态分别验证 |
| `ruby` | SE-07, OP-05, IN-03 | 原生 Core；任务持久性归应用 |
| `elixir` | SE-06, OP-03, CS-06 | 原生 Core；OTP 监督不是 exactly-once |
| `erlang` | SE-06, IN-02 | 原生 Core；有界 actor 消息与应用监督 |
| `lua` | IN-06, PE-05 | 嵌入宿主的原生 Core；无独立设备权限 |
| `dart` | SE-01, OP-02, PE-02 | 原生 Core；平台/UI 权限单独验证 |
| `swift` | OP-02, HC-02, PE-02 | 原生 Core；OS 运行与包验证分开 |
| `julia` | SC-02, SC-03, IN-04 | 原生 Core；确定性数值安全约束 |
| `haskell` | SE-04, SC-01, PE-01 | 原生 Core；类型化计划不是运行安全证明 |
| `matlab` | SC-06 | MATLAB/Octave 共享源码；原生 MATLAB 未验证 |
| `octave` | SC-05, SC-06 | 共享源码，在 GNU Octave 运行 |
| `perl` | SE-02, CS-07, FC-06 | 原生 Core；固定日志/文本，不开放任意 Shell |
| `delphi` | SE-03, OP-04, FC-04 | 原生 Core；Free Pascal 不代表商业 Delphi |
| `ocaml` | SE-05, FC-05, IN-05 | 原生 Core；应用拥有依赖图与审核人 |
| `objc` | HC-02, PE-03 | 原生 Objective-C Core；GNUstep 与 Apple 分开 |
| `nim` | IN-01, IN-06 | 原生 Core；传感器/执行器仍为 fixture |
| `v` | IN-02, PE-05 | 原生 Core；受限宿主回调 |
| `d` | SE-07, OP-07, FC-02 | 原生 Core；依赖/注册表版本单独检查 |
| `zig` | IN-04, PE-04 | 原生 Core；仅模拟，无设备协议或硬件声明 |
| `powershell` | SE-07, OP-01 | 共享 C# Core；不重复实现 loop |

JavaScript、Kotlin、Scala、Groovy、Clojure、Visual Basic、F#、OpenCL 保持宿主 Core
Sample；Shell、Lisp、Tcl、Prolog 保持 Bridge。不能重复计作独立 Core。
本目录不启动 Ada、Mojo 等尚在计划中的语言。

## 每个切片的验收

1. 写明场景 ID、语言、SDK 版本/源码模式与非目标。
2. 记录规划步骤和应用状态；不把记忆提升成指令，不假设 SDK 自动召回。
3. 至少两次工具/结果/决策步骤，最终工具范围显式限定。
4. 检查效果前拒绝、畸形输入、依赖失败；按能力检查取消、审批编辑后的重授权。
5. 外部动作默认模拟或仅草案；真实动作须单独验证身份、审批、幂等/对账与隔离。
6. 提供命令、预期输出、失败非零退出与自动化测试。
7. 分别记录源码、本地、CI、真实 Provider 与独立复现；可选 live 模式不等于已运行。
8. 复用现有 Core API；可复用 API/wire 缺口先过 spec、兼容性与各语言 parity 门禁。

教程或确定性 fixture 通过不产生部署、临床、金融、实验室、电网、机器人或安全保证。
