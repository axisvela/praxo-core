from __future__ import annotations

import argparse
import json
import re
from collections import Counter
from pathlib import Path

import check_example_coverage as coverage


ROOT = Path(__file__).resolve().parents[1]
SOURCE = "https://github.com/axisvela/praxo-core/tree/main/"
INDUSTRIES = {
    "SE": ("Software And IT", "软件工程与 IT 运维"),
    "OP": ("Enterprise Operations", "企业运营与办公"),
    "CS": ("Service And Commerce", "客服、营销与商业"),
    "FC": ("Finance And Compliance", "金融、财税与合规"),
    "SC": ("Science And Research", "科研与数据分析"),
    "IN": ("Industry And Energy", "工业、供应链与能源"),
    "HC": ("Healthcare", "医疗健康"),
    "PE": ("Personal And Education", "个人、教育与具身"),
    "CY": ("Cybersecurity", "网络安全与攻防对抗"),
    "CT": ("Smart Cities And Public Governance", "智慧城市与公共治理"),
    "TL": ("Transport Shipping And Aviation", "交通物流、航运与低空经济"),
    "MD": ("Media Design Games And Content", "传媒、设计、游戏与数字内容"),
    "LJ": ("Law Justice And Intellectual Property", "法律、司法与知识产权"),
    "BE": ("Built Environment Mining And Property", "建筑工程、矿业与空间运营"),
    "AE": ("Agriculture Forestry And Conservation", "农业、林业与生态保护"),
    "OG": ("Organization Architecture And Collaboration", "组织治理、架构与跨学科协同"),
    "CORE": ("Cross-Industry Foundations", "跨行业基础能力"),
}
TUTORIALS = {
    "order-review": ("CS", "tools,policy,http", "CS-01,CS-05"),
    "office-qa": ("OP", "retrieval,citations,policy", "OP-03,OP-06,MD-02"),
    "customer-support": ("CS", "streaming,citations,http,policy", "CS-01"),
    "wealth-service": ("FC", "tools,draft,http,policy", "FC-01,FC-02"),
    "sales-crm": ("CS", "tools,draft,http,policy", "CS-03"),
    "windows-diagnostics": ("SE", "tools,host,policy", "SE-06,OP-01"),
    "log-triage": ("SE", "tools,analysis,policy", "SE-02,SE-06,CY-03"),
    "data-quality": ("SC", "analysis,tools,policy", "SC-06"),
    "batch-exception-review": ("FC", "batch,tools,policy", "FC-03,FC-04"),
    "experiment-comparison": ("SC", "analysis,tools,policy", "SC-06"),
    "signal-trends": ("SC", "analysis,tools,policy", "SC-05,IN-01,CT-02,TL-04"),
    "host-embedding": ("IN", "host,tools,draft,policy", "IN-06,PE-05,MD-03,AE-03"),
    "iot-gateway": ("IN", "host,tools,draft,policy", "IN-01,IN-06"),
    "gateway-health": ("IN", "host,tools,draft,policy", "IN-01,IN-04"),
    "device-diagnostics": ("IN", "host,tools,draft,policy", "IN-01,IN-06"),
    "industrial-edge": ("IN", "host,tools,draft,policy", "IN-01"),
    "incident-coordination": ("SE", "tools,draft,events,policy", "SE-06"),
    "simulation-metrics": ("SC", "analysis,tools,draft,policy", "SC-04,SC-06"),
    "insurance-claims": ("FC", "structured-output,analysis,tools,draft,policy", ""),
    "marketing-segmentation": ("CS", "analysis,tools,draft,policy", "CS-04,CS-06"),
    "soc-alert-triage": ("SE", "pii,tools,draft,events,policy", "SE-05,PE-03,CY-02,CY-06"),
    "legal-compliance": ("FC", "citations,approval,tools,policy", "FC-05,FC-06,LJ-04"),
    "logistics-checkpoint": ("IN", "checkpoint,tools,draft,policy", "IN-03,TL-05,OG-06"),
    "evidence-vault": ("SE", "filesystem,tools,draft,policy", "SE-05,PE-03,LJ-01"),
    "wealth-analysis": ("FC", "analysis,tools,draft,policy", "FC-01,FC-02"),
    "healthcare-scheduling": ("HC", "tools,draft,policy", ""),
    "travel-booking": ("PE", "tools,draft,policy", "PE-02,TL-07"),
    "education-tutoring": ("PE", "retrieval,citations,tools,draft,policy", "PE-01"),
    "finops-review": ("SE", "analysis,tools,draft,policy", "SE-07"),
    "api-orchestration": ("SE", "tools,orchestration,draft,policy", "SE-08"),
    "meeting-coordination": ("OP", "tools,draft,policy", "OP-02"),
    "literature-review": ("SC", "retrieval,citations,tools,draft,policy", "SC-01"),
    "maintenance-triage": ("IN", "tools,draft,policy", "IN-01"),
    "executive-brief": ("OP", "analysis,tools,draft,policy", "OP-07"),
    "production-scheduling": ("IN", "analysis,tools,draft,policy", "IN-02"),
    "knowledge-maintenance": ("OP", "analysis,tools,draft,policy", "OP-03"),
    "aiops-rca": ("SE", "analysis,tools,draft,policy", "SE-06"),
    "code-review": ("SE", "analysis,tools,draft,policy", "SE-05"),
    "legacy-migration": ("SE", "analysis,tools,draft,policy", "SE-03"),
    "privacy-agent": ("PE", "analysis,tools,draft,policy", "PE-03"),
    "retail-replenishment": ("CS", "analysis,tools,draft,policy", "CS-05"),
    "zero-trust-review": ("CY", "analysis,tools,draft,policy", "CY-05"),
    "internal-service-desk": ("OP", "tools,draft,policy", "OP-01"),
    "rpa-reconciliation": ("OP", "analysis,tools,draft,policy", "OP-04"),
    "recruiting-match": ("OP", "analysis,tools,draft,policy", "OP-05"),
    "quant-risk": ("FC", "analysis,tools,draft,policy", "FC-02"),
    "onboarding-plan": ("OP", "tools,draft,policy", "OP-06"),
    "credit-diligence": ("FC", "analysis,tools,draft,policy", "FC-03"),
    "contract-review": ("FC", "analysis,tools,draft,policy", "FC-05"),
    "clinical-guidelines": ("HC", "retrieval,citations,tools,draft,policy", "HC-01"),
    "bom-review": ("IN", "analysis,tools,draft,policy", "IN-05"),
    "trial-screening": ("HC", "analysis,tools,draft,policy", "HC-03"),
    "public-approval": ("CT", "tools,draft,policy", "CT-03"),
    "pentest-lab-review": ("CY", "tools,draft,policy", "CY-01"),
    "storyboard-previs": ("MD", "tools,draft,policy", "MD-01"),
    "traffic-signal-plan": ("CT", "analysis,tools,draft,policy", "CT-01"),
    "drone-fleet-plan": ("TL", "tools,draft,policy", "TL-01"),
    "phishing-awareness": ("CY", "analysis,tools,draft,policy", "CY-04"),
    "supply-chain-review": ("CY", "analysis,tools,draft,policy", "CY-07"),
    "construction-safety": ("BE", "analysis,tools,draft,policy", "BE-01"),
    "news-factcheck": ("MD", "analysis,tools,draft,policy", "MD-02"),
    "emergency-route-plan": ("CT", "analysis,tools,draft,policy", "CT-04"),
    "patent-fto": ("LJ", "analysis,tools,draft,policy", "LJ-02"),
    "community-governance": ("OG", "analysis,tools,draft,policy", "OG-04"),
    "world-economy": ("MD", "tools,draft,policy", "MD-03"),
    "architecture-graph": ("OG", "analysis,tools,draft,policy", "OG-01"),
    "pollution-tracing": ("CT", "analysis,tools,draft,policy", "CT-05"),
    "live-show": ("MD", "tools,draft,policy", "MD-07"),
    "waste-collection": ("CT", "analysis,tools,draft,policy", "CT-06"),
    "negotiation-interpretation": ("OG", "analysis,tools,draft,policy", "OG-03"),
    "biodiversity-alerts": ("AE", "analysis,tools,draft,policy", "AE-05"),
    "budget-review": ("CT", "analysis,tools,draft,policy", "CT-07"),
    "copyright-evidence": ("LJ", "tools,draft,policy", "LJ-05"),
    "due-diligence": ("LJ", "analysis,tools,draft,policy", "LJ-03"),
    "dubbing-plan": ("MD", "tools,draft,policy", "MD-04"),
    "tender-review": ("BE", "analysis,tools,draft,policy", "BE-04"),
    "hedge-plan": ("AE", "analysis,tools,draft,policy", "AE-04"),
    "audiobook-production": ("MD", "tools,draft,policy", "MD-06"),
    "eda-placement": ("OG", "analysis,tools,draft,policy", "OG-05"),
    "digital-twin-memory": ("OG", "state,tools,draft,policy", "OG-06"),
    "litigation-timeline": ("LJ", "analysis,tools,draft,policy", "LJ-01"),
    "precedent-outline": ("LJ", "analysis,tools,draft,policy", "LJ-04"),
    "property-forecast": ("BE", "analysis,tools,draft,policy", "BE-05"),
    "virtual-pi": ("OG", "analysis,tools,draft,policy", "OG-07"),
    "fire-spread": ("AE", "analysis,tools,draft,policy", "AE-02"),
    "mining-slope": ("BE", "analysis,tools,draft,policy", "BE-03"),
    "livestock-monitor": ("AE", "analysis,tools,draft,policy", "AE-01"),
    "mesh-review": ("MD", "analysis,tools,draft,policy", "MD-05"),
    "aquaculture-water": ("AE", "analysis,tools,draft,policy", "AE-03"),
    "customs-reroute": ("TL", "analysis,tools,draft,policy", "TL-05"),
    "cold-chain": ("TL", "analysis,tools,draft,policy", "TL-04"),
}
GUIDES = {
    "workspace-agent-tutorial": ("SE", "go", "filesystem,tools,policy"),
    "python-structured-output-app": ("SC", "python", "structured-output,batch,checkpoint"),
    "representative-chain-tutorial": ("CORE", "go", "delegation,mcp,events,policy"),
    "mcp-tutorial": ("CORE", "go", "mcp,tools"),
    "structured-output-tutorial": ("CORE", "multiple", "structured-output"),
    "embedded-service-tutorial": ("CORE", "multiple", "http,policy"),
}
LEGACY_NAMES = {
    "Knowledge Q&A and document assistant": "OP", "Customer service / contact center": "CS",
    "Marketing content and segmentation": "CS", "Office productivity": "OP", "Sales / CRM": "CS",
    "Wealth / retail finance": "FC", "Insurance claims": "FC", "Procurement / ERP": "OP",
    "Factory / manufacturing": "IN", "Industrial automation": "IN", "Consumer electronics": "IN",
    "Robotics": "PE", "Logistics": "IN", "Energy / grid": "IN", "Security / SOC": "SE",
    "Healthcare scheduling": "HC", "Legal / compliance": "FC", "Education / tutoring": "PE",
    "Media / content": "CS", "Travel / booking": "PE", "Retail / e-commerce": "CS", "Data platform": "SC",
}


def heading(path: Path) -> str:
    return path.read_text(encoding="utf-8").splitlines()[0].lstrip("# ")


def records() -> list[dict]:
    entries = []
    scenario = ROOT / "docs/getting-started/agent-scenarios.md"
    for line in scenario.read_text(encoding="utf-8").splitlines():
        match = re.match(r"^\| ([A-Z]{2}-\d{2}) \| ([^|]+) \| ([^|]+) \|", line)
        if match:
            key, title, targets = (value.strip() for value in match.groups())
            cells = [cell.strip() for cell in line.split("|")]
            related_text = cells[5] if len(cells) >= 8 else cells[4]
            slices = re.findall(re.escape(SOURCE) + r"([^\s)]+)", related_text)
            entries.append(dict(id=key, kind="candidate", industry=key[:2], title=title,
                                languages=targets, status="candidate", full_implementation="not-implemented",
                                related_slices=sorted(set(slices)),
                                path="docs/getting-started/agent-scenarios.md"))
    plan = (ROOT / "docs/getting-started/tutorial-plan.md").read_text(encoding="utf-8")
    for line in plan.splitlines():
        cells = [cell.strip() for cell in line.split("|")]
        if len(cells) >= 5 and cells[1] in LEGACY_NAMES:
            name = cells[1]
            entries.append(dict(id=f"legacy:{name}", kind="legacy-theme", title=name,
                                industry=LEGACY_NAMES[name], languages=cells[2],
                                path="docs/getting-started/tutorial-plan.md"))
    for readme in sorted((ROOT / "language").glob("*/Tutorial/*/README.md")):
        language, slug = readme.parts[-4], readme.parent.name
        industry, capabilities, related = TUTORIALS[slug]
        entries.append(dict(id=f"tutorial:{language}:{slug}", kind="application", title=heading(readme),
                            industry=industry, languages=language, capabilities=capabilities,
                            related=related, path=readme.parent.relative_to(ROOT).as_posix()))
    for slug, (industry, language, capabilities) in GUIDES.items():
        path = ROOT / "docs/guides" / f"{slug}.md"
        entries.append(dict(id=f"guide:{slug}", kind="guide", industry=industry, languages=language,
                            title=heading(path), capabilities=capabilities, path=path.relative_to(ROOT).as_posix()))
    for language in coverage.languages():
        for theme in coverage.ALIGNED_THEMES:
            path = coverage.example_path(language, theme)
            if (path / "README.md").is_file() and coverage.implementation_files(path):
                entries.append(dict(id=f"mechanism:{language}:{theme}", kind="mechanism", industry="CORE",
                                    languages=language, title=theme, capabilities=theme,
                                    path=path.relative_to(ROOT).as_posix()))
        for theme in coverage.ADVANCED_THEMES:
            path = coverage.advanced_path(language, theme)
            if (path / "README.md").is_file() and coverage.implementation_files(path):
                entries.append(dict(id=f"advanced:{language}:{theme}", kind="advanced", industry="CORE",
                                    languages=language, title=theme, capabilities=theme,
                                    path=path.relative_to(ROOT).as_posix()))
    indexed = {(entry["languages"], entry["path"]) for entry in entries}
    sources = [(language, readme.parent) for language in coverage.languages()
               for readme in (ROOT / "language" / language / "examples").glob("*/README.md")]
    sources += [("go", readme.parent) for pattern in ("examples/*/README.md", "examples/recipes/*/README.md")
                for readme in ROOT.glob(pattern)]
    for language, path in sorted(sources):
        relative = path.relative_to(ROOT).as_posix()
        if (language, relative) in indexed or not coverage.implementation_files(path):
            continue
        entries.append(dict(id=f"source:{language}:{relative}", kind="source-example", industry="CORE",
                            languages=language, title=path.name, capabilities=path.name, path=relative))
        indexed.add((language, relative))
    for entry in entries:
        if entry["kind"] == "candidate":
            slices = {item["path"] for item in entries if item["kind"] == "application"
                      and entry["id"] in item["related"].split(",")}
            entry["related_slices"] = sorted(set(entry["related_slices"]) | slices)
    return entries


def render(entries: list[dict], zh: bool = False) -> str:
    counts = Counter(entry["kind"] for entry in entries)
    translated = {}
    if zh:
        text = (ROOT / "docs/zh-CN/getting-started/agent-scenarios.md").read_text(encoding="utf-8")
        translated = dict(re.findall(r"^\| ([A-Z]{2}-\d{2}) \| ([^|]+) \|", text, re.M))
    applications = [entry for entry in entries if entry["kind"] == "application"]
    guides = [entry for entry in entries if entry["kind"] == "guide"]
    languages = coverage.languages()
    lines = ["# 教程与场景总目录" if zh else "# Tutorial And Scenario Catalog", ""]
    lines += (["统一入口：按行业、语言、场景 ID、能力和条目类型查找既有教程与候选场景。",
               "本页由 `scripts/tutorial_catalog.py` 从实际源码路径与场景目录生成，不移动既有文件。"] if zh else
              ["One entry point by industry, language, scenario ID, capability and entry type.",
               "Generated by `scripts/tutorial_catalog.py` from source paths and scenario catalogs; published files do not move."])
    lines += ["", "## 计数口径" if zh else "## Counting Rules", ""]
    lines += (["总目录有 **%d 个索引条目**，不是同等数量的独立行业场景或已验证应用。" % len(entries),
               "语言副本、跨语言矩阵、重叠主题与教程切片不能相加为独立场景数。"] if zh else
              ["There are **%d indexed entries**, not that many distinct industry scenarios or verified applications." % len(entries),
               "Language variants, overlapping themes, mechanism cells and tutorial slices are not additive unique scenarios."])
    lines += ["", "| 类型 / Type | 数量 / Count |", "| --- | ---: |"]
    labels = {
        "candidate": ("New candidate goals (not implementations)", "新增候选目标（非实现）"),
        "legacy-theme": ("Earlier broad scenario themes (overlap the new goals)", "之前的宽泛场景主题（与新增目标重叠）"),
        "application": ("Application tutorial language paths", "应用教程语言路径"),
        "guide": ("Cross-cutting tutorial guides (overlap source paths)", "跨主题教程指南（与源码入口重叠）"),
        "mechanism": ("Language/theme mechanism source entries", "语言/机制主题源码条目"),
        "advanced": ("Advanced language/theme source entries", "进阶语言/主题源码条目"),
        "source-example": ("Other source examples and recipes", "其他源码示例与 recipes"),
    }
    for kind, label in labels.items():
        lines.append(f"| {label[zh]} | {counts[kind]} |")
    goals = [entry for entry in entries if entry["kind"] == "candidate"]
    with_slices = sum(bool(entry["related_slices"]) for entry in goals)
    complete = sum(entry["full_implementation"] == "implemented" for entry in goals)
    lines += ["", (f"完整场景目标：**{len(goals)}**；其中 **{with_slices}** 个关联已有局部切片；"
                   f"完整实现：**{complete}**。有关联的目标仍是候选，切片关系不额外增加条目计数。" if zh else
                   f"Full scenario goals: **{len(goals)}**; **{with_slices}** have related partial slices; "
                   f"full implementations: **{complete}**. Related goals remain candidates; slice relations do not add indexed entries.")]
    lines += ["", ("MATLAB/Octave 的两条入口共享实现，不是两个独立场景；未运行原生 MATLAB。" if zh else
                    "The MATLAB/Octave paths share an implementation, not two unique scenarios; native MATLAB is unverified."),
              ("存在 README 与源码只证明入口存在，不证明已运行或通过 CI。运行证据见 [Tutorial 状态](tutorial-plan.md) 与 [验证证据](../project/verification-evidence.md)。" if zh else
               "README and source existence is not runtime or CI verification. See [Tutorial status](tutorial-plan.md#current-status) and [verification evidence](../project/verification-evidence.md)."),
              "", "## 按行业与场景" if zh else "## By Industry And Scenario", ""]
    for industry, names in INDUSTRIES.items():
        if industry == "CORE":
            continue
        candidates = [entry for entry in entries if entry["kind"] == "candidate" and entry["industry"] == industry]
        legacy = [entry for entry in entries if entry["kind"] == "legacy-theme" and entry["industry"] == industry]
        lines += [f"### {names[zh]}", ""]
        lines += [("候选 ID：" if zh else "Candidate IDs: ") + ", ".join(f"`{entry['id']}`" for entry in candidates) + "."]
        lines += [("旧场景主题：" if zh else "Earlier themes: ") + ("; ".join(entry["title"] for entry in legacy) or "-") + ".", ""]
        lines += ["| 目标 / Goal | 候选语言 / Targets | 目标状态 / Goal Status | 相关切片 / Related Slices | 完整实现 / Full Implementation |",
                  "| --- | --- | --- | --- | --- |"]
        for entry in candidates:
            links = ", ".join(f"[{path.split('/')[-1]}]({SOURCE}{path})" for path in entry["related_slices"]) or "-"
            title = translated.get(entry["id"], entry["title"]).strip()
            lines.append(f"| `{entry['id']}` {title} | {entry['languages']} | {'候选' if zh else 'Candidate'} | {links} | {'未实现' if zh else 'Not implemented'} |")
        lines += [""]
        lines += ["| 教程 / Tutorial | 语言 / Language | 能力 / Capabilities | 相关目标 / Related Goals |", "| --- | --- | --- | --- |"]
        for entry in applications + guides:
            if entry["industry"] == industry or any(key.startswith(industry + "-") for key in entry.get("related", "").split(",")):
                path = SOURCE + entry["path"]
                lines.append(f"| [{entry['title']}]({path}) | {entry['languages']} | {entry['capabilities']} | {entry.get('related') or '-'} |")
        lines += [""]
    lines += [("完整的 100 个目标与语言候选分配见 [场景目录](agent-scenarios.md)；旧主题和状态仍见 [Tutorial Plan](tutorial-plan.md)。相关目标不表示完整目标已实现。" if zh else
               "All hundred goals and language targets are in the [scenario catalog](agent-scenarios.md); earlier themes and status remain in the [Tutorial Plan](tutorial-plan.md). Related goals do not imply full scenario completion."),
              "", "## 按语言" if zh else "## By Language", "",
              "| Core | 应用教程 / Application Paths | 机制 / Mechanisms | 进阶 / Advanced | 其他源码 / Other Source |",
              "| --- | --- | ---: | ---: | ---: |"]
    for language in languages:
        tutorials = [entry for entry in applications if entry["languages"] == language]
        links = ", ".join(f"[{entry['path'].split('/')[-1]}]({SOURCE}{entry['path']})" for entry in tutorials) or "-"
        mechanism = sum(entry["kind"] == "mechanism" and entry["languages"] == language for entry in entries)
        advanced = sum(entry["kind"] == "advanced" and entry["languages"] == language for entry in entries)
        other = sum(entry["kind"] == "source-example" and entry["languages"] == language for entry in entries)
        lines.append(f"| [{language}]({SOURCE}language/{language}) | {links} | {mechanism} | {advanced} | {other} |")
    lines += ["", ("缺少应用教程的语言不等于缺少 Core；候选分配与实现验证分开。PowerShell 共享 C#；Sample/Bridge 不新增独立 Core。" if zh else
                    "A missing application tutorial is not a missing Core. Candidate allocation and runtime verification are separate. PowerShell shares C#; Sample/Bridge entries do not add Cores."),
              "", "## 按能力" if zh else "## By Capability", "",
              "| 能力 / Capability | 应用教程 / Application Paths |", "| --- | --- |"]
    capabilities = sorted({tag for entry in applications for tag in entry["capabilities"].split(",")})
    for capability in capabilities:
        links = [f"[{entry['languages']}/{entry['path'].split('/')[-1]}]({SOURCE}{entry['path']})"
                 for entry in applications if capability in entry["capabilities"].split(",")]
        lines.append(f"| {capability} | {', '.join(links)} |")
    lines += ["", "## 基础与进阶示例" if zh else "## Foundation And Advanced Examples", "",
              ("这些跨行业条目复用原来的 examples/recipes 路径，不重命名为新的行业场景。" if zh else
               "These cross-industry entries retain their examples/recipes paths and are not renamed as new industry scenarios."),
              "", "| 主题 / Theme | 语言条目 / Language Entries | 入口 / Entry |", "| --- | ---: | --- |"]
    for theme in (*coverage.ALIGNED_THEMES, *coverage.ADVANCED_THEMES):
        matching = [entry for entry in entries if entry["kind"] in {"mechanism", "advanced"} and entry["title"] == theme]
        lines.append(f"| {theme} | {len(matching)} | [Language Coverage](language-coverage.md) |")
    lines += ["", "### 其他示例与 Recipes" if zh else "### Other Examples And Recipes", "",
              "| 主题 / Theme | 源码入口 / Source Entries |", "| --- | --- |"]
    others = [entry for entry in entries if entry["kind"] == "source-example"]
    for title in sorted({entry["title"] for entry in others}):
        links = [f"[{entry['languages']}]({SOURCE}{entry['path']})" for entry in others if entry["title"] == title]
        lines.append(f"| {title} | {', '.join(links)} |")
    lines += ["", "| 指南 / Guide | 范围 / Scope |", "| --- | --- |"]
    for entry in guides:
        lines.append(f"| [{entry['title']}]({SOURCE}{entry['path']}) | {entry['capabilities']} |")
    lines += ["", "## 维护与导出" if zh else "## Maintenance And Export", "", "```bash",
              "python scripts/tutorial_catalog.py", "python scripts/tutorial_catalog.py --check",
              "python scripts/tutorial_catalog.py --json", "python scripts/test_tutorial_catalog.py", "```", "",
              ("JSON 包含逐条语言/机制源码路径，供筛选和统计。规划、源码存在、本地运行、CI、实网与独立采用必须保持不同证据层级。" if zh else
               "JSON exports every language/theme source path for filtering. Planning, source presence, local runs, CI, live integration and independent adoption remain different evidence levels."), ""]
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()
    entries = records()
    if args.json:
        print(json.dumps({"counts": dict(Counter(entry["kind"] for entry in entries)), "entries": entries}, ensure_ascii=True))
        return 0
    stale = []
    for zh, prefix in ((False, ""), (True, "zh-CN/")):
        path = ROOT / f"docs/{prefix}getting-started/tutorial-catalog.md"
        content = render(entries, zh)
        if args.check:
            if not path.is_file() or path.read_text(encoding="utf-8") != content:
                stale.append(path.relative_to(ROOT).as_posix())
        else:
            path.write_text(content, encoding="utf-8")
    if stale:
        print("Stale tutorial catalogs: " + ", ".join(stale))
        return 1
    print(dict(Counter(entry["kind"] for entry in entries)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
