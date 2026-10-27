# 语言支持总表

本表覆盖[规范语言支持矩阵](https://github.com/axisvela/praxo-core/blob/main/spec/languages.md)中的所有语言，包括计划中和需要明确消费者的条目。站点构建时直接读取规范矩阵生成，状态、源码标签与范围不重复维护。

**最终目标：**具备原生实现能力的独立语言以 Framework 为目标。Wire 是中间阶段，除非明确记录的语言或运行时技术限制阻止完整实现。Bridge 和 Sample 描述当前交付形式，本身不构成永久能力限制。新增原生循环前仍需要明确消费者和维护者。

**状态说明：**“源码已发布”只表示源码发布，不代表包管理器已发布或生产就绪；“开发中”不是正式发布；“计划中”和“需消费者”不承诺交付日期。源码标签与共享 `SPEC_VERSION` 独立，“—”表示未声明标签。

备注是当前声明范围与证据，不代表与 Go 全部功能一致。C 历史上归类为 Core，但当前公开 API 仍为 wire 级别。具体 CI 任务和阶段门禁见[规范矩阵](https://github.com/axisvela/praxo-core/blob/main/spec/languages.md)和[语言实现支持政策](support.md)。备注保留规范矩阵中的英文，避免翻译副本与事实漂移。

<!-- language-support-matrix -->
