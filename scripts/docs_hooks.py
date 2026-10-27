from pathlib import Path
import re
from urllib.parse import urljoin


ROOT = Path(__file__).resolve().parents[1]
REPOSITORY = "https://github.com/axisvela/praxo-core/blob/main/"
LEGACY_PATHS = {
    "00-overview.md": "getting-started/overview.md",
    "quickstart.md": "getting-started/quickstart.md",
    "adoption.md": "getting-started/adoption.md",
    "01-architecture.md": "reference/architecture.md",
    "02-primitives.md": "reference/primitives.md",
    "03-integration.md": "guides/integration.md",
    "04-license-and-provenance.md": "project/provenance.md",
    "05-compatibility.md": "project/compatibility.md",
    "06-roadmap.md": "project/roadmap.md",
    "07-api-freeze.md": "project/api-stability.md",
    "08-security.md": "security/index.md",
    "09-release.md": "project/releasing.md",
    "10-plugin-authoring.md": "guides/plugins.md",
    "11-migration-v2.md": "project/migration-v2.md",
    "12-ecosystem.md": "integrations/ecosystem.md",
    "13-multi-agent.md": "guides/multi-agent.md",
    "14-workspace-session.md": "reference/workspace-session.md",
    "15-plugin-trust-sbom.md": "security/plugin-trust.md",
    "16-compatibility-policy.md": "project/compatibility-policy.md",
    "17-multilingual-sdk.md": "contributing/sdk-design.md",
    "18-multilingual-roadmap.md": "languages/support.md",
    "19-language-expansion.md": "contributing/language-policy.md",
    "adapters.md": "integrations/index.md",
    "benchmarks.md": "project/benchmarks.md",
    "comparison.md": "project/comparison.md",
    "containment-review.md": "security/containment.md",
    "documentation-index.md": "getting-started/index.md",
    "event-schema.md": "reference/events.md",
    "recipes.md": "guides/recipes.md",
    "sdks.md": "languages/index.md",
}
MOVED_LANGUAGE_PAGES = (
    "index support go python typescript javascript java kotlin scala rust c cpp "
    "csharp visual-basic php ruby perl lua dart swift julia r d zig cobol fortran "
    "haskell shell powershell"
).split()
LEGACY_PATHS.update({f"sdks/{page}.md": f"languages/{page}.md"
                     for page in MOVED_LANGUAGE_PAGES})


def language_matrix(markdown, chinese=False):
    section = markdown.split("## Matrix\n", 1)[1].split("\n## ", 1)[0]
    rows = []
    seen = set()
    stages = {"Core": "Framework (Core)", "Core (reference)": "Framework (reference)",
              "Core (.NET)": "Framework (.NET)", "Wire": "Wire", "Wire / Bridge": "Wire / Bridge",
              "Bridge": "Bridge", "Bridge / extension": "Bridge / extension",
              "Sample": "Sample", "Sample (.NET)": "Sample (.NET)",
              "Sample (TypeScript)": "Sample (TypeScript)", "Sample (JVM)": "Sample (JVM)"}
    statuses = {"released": "源码已发布", "in progress": "开发中", "planned": "计划中", "consumer-gated": "需消费者"}
    maturities = {"reference": "参考实现", "complete": "完整", "partial": "部分完成",
                  "sample": "示例", "planned": "计划中", "gated": "需消费者"}
    for line in section.splitlines():
        if not line.startswith("| ") or line.startswith("| Language") or line.startswith("| ---"):
            continue
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if len(cells) != 6:
            raise ValueError("invalid language matrix row: " + line)
        name, stage, status, tag, maturity, notes = cells
        if name in seen or stage not in stages or status not in statuses or maturity not in maturities:
            raise ValueError("duplicate or unknown language matrix value: " + line)
        seen.add(name)
        slug = {"C++": "cpp", "C#": "csharp", "F#": "fsharp", "OCaml / Caml": "ocaml"}.get(name, name.lower().replace(" ", "-"))
        if (ROOT / "docs/languages" / (slug + ".md")).is_file():
            name = f"[{name}]({slug}.md)"
        rows.append((name, stages[stage], statuses[status] if chinese else status,
                     "—" if chinese and tag == "none" else tag,
                     maturities[maturity] if chinese else maturity, notes))
    if not rows:
        raise ValueError("language matrix is empty")
    header = ("语言", "当前阶段 / 形式", "状态", "源码标签", "成熟度", "当前范围与证据（英文）") if chinese else ("Language", "Current stage / form", "Status", "Source tag", "Maturity", "Current scope and evidence")
    return "\n".join(["| " + " | ".join(header) + " |", "| " + " | ".join(["---"] * len(header)) + " |"] +
                     ["| " + " | ".join(row) + " |" for row in rows])


def on_config(config):
    redirects = config.plugins["redirects"].config["redirect_maps"]
    redirects.update(LEGACY_PATHS)
    redirects.update({"zh-CN/" + old: "zh-CN/" + new
                      for old, new in LEGACY_PATHS.items()
                      if (ROOT / "docs/zh-CN" / new).exists()})
    redirects.update({"zh-CN/sdks/" + page + ".md":
                      urljoin(config.site_url, "zh-CN/languages/" + page + "/")
                      for page in MOVED_LANGUAGE_PAGES
                      if not (ROOT / "docs/zh-CN/languages" / (page + ".md")).exists()})
    return config


def sdk_readme(markdown, source):
    base = REPOSITORY + source

    def replace(match):
        target = match[2]
        if target.startswith("#") or re.match(r"[a-zA-Z][\w+.-]*:", target):
            return match[0]
        return match[1] + urljoin(base, target) + match[3]

    return re.sub(r"(!?\[[^\]\n]*\]\()([^\s)]+)([^)\n]*\))", replace, markdown)


def on_page_markdown(markdown, page, config, files):
    if "<!-- language-support-matrix -->" in markdown:
        source = (ROOT / "spec/languages.md").read_text(encoding="utf-8")
        markdown = markdown.replace("<!-- language-support-matrix -->", language_matrix(source, page.file.src_uri.startswith("zh-CN/")))
    source = page.meta.get("sdk_readme")
    if source:
        path = (ROOT / source).resolve()
        if not path.is_relative_to(ROOT) or path.name != "README.md":
            raise ValueError("SDK documentation must reference a repository README.md")
        return markdown + "\n\n" + sdk_readme(path.read_text(encoding="utf-8"), source)
    return markdown
