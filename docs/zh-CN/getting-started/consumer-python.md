# Python 独立消费者

在自己的应用中使用已发布的 `praxo-core==0.3.0`，要求 Python 3.11 或更新版本。
无需检出 PRAXO-CORE 源码、API Key、模型服务或 AxisVela 产品。安装需要 PyPI 访问或已有 wheel 缓存。

## 选择边界

适用于需要异步模型/工具循环、显式工具范围和 Policy 的嵌入式应用。应用仍负责模型访问、
真实身份、持久审批、外部效果和隔离。它不是托管 Agent 平台、持久图引擎或沙箱服务。
选型前阅读[何时不应选择 Core](when-not-to-use.md)。

## 在新应用安装

在新的应用目录创建虚拟环境，直接使用其中的 Python，无需激活。

POSIX：

```sh
python3 -m venv .venv
.venv/bin/python -m pip install --index-url https://pypi.org/simple praxo-core==0.3.0
```

PowerShell：

```powershell
python -m venv .venv
.venv\Scripts\python.exe -m pip install --index-url https://pypi.org/simple praxo-core==0.3.0
```

不要使用 `pip install -e`、仓库路径或 `PYTHONPATH` 替换 SDK。验收测试检查安装版本、
包位于虚拟环境内，以及不存在直接路径安装记录。

## 应用源码

以下为 `starter.py`。文档站直接渲染[受测应用源码](https://github.com/axisvela/praxo-core/blob/main/examples/consumer-python/starter.py)，
在 GitHub 阅读时可通过源码链接查看。

<!-- python-consumer-source: starter.py -->

## 验收测试

以下为 `test_starter.py`，直接来自[受测源码](https://github.com/axisvela/praxo-core/blob/main/examples/consumer-python/test_starter.py)。

<!-- python-consumer-source: test_starter.py -->

## 验证

POSIX：

```sh
.venv/bin/python -m pip check
.venv/bin/python -I -m unittest discover -s . -v
.venv/bin/python -I starter.py
```

PowerShell：

```powershell
.venv\Scripts\python.exe -m pip check
.venv\Scripts\python.exe -I -m unittest discover -s . -v
.venv\Scripts\python.exe -I starter.py
```

程序预期输出：

```text
allow: recorded; effects=1
deny: policy rejected; effects=0
```

模型是确定性 fixture，不是真实 LLM。`allowed_tools` 限制工具名，Policy 额外检查目标
参数。当前 API 的空范围不表示 deny-all。被拒绝的 private 目标不得到达内存效果计数器。
替换为真实模型适配器后仍需保留这些测试。

## 治理验收

`test_governed.py` 增加五项负向检查：

```sh
.venv/bin/python -I -m unittest discover -s . -p "test_governed.py" -v
```

| 检查 | 必须结果 |
| --- | --- |
| 缺少必需 Policy | 应用守卫在运行前拒绝；工具零副作用 |
| 工具范围为空 | 应用守卫拒绝；工具零副作用 |
| Middleware 改变最终参数 | 最终操作重新授权；拒绝阻止副作用 |
| 审批编辑改变参数 | 编辑后的操作重新授权；拒绝阻止副作用 |
| Policy 服务错误 | 运行 fail closed；工具零副作用 |

使用[受测源码](https://github.com/axisvela/praxo-core/blob/main/examples/consumer-python/test_governed.py)。
守卫属于应用层：Core 保留普通 nil-policy 行为。这些检查不证明真实身份、持久审批、
效果对账或通用安全 Profile。

这些检查仅证明指定发布包与 fixture 行为，不证明真实模型质量、生产安全或持久执行保证。
后续参考[Python API 与实现指南](../languages/python/index.md)及[安全模型](../security/index.md)。
