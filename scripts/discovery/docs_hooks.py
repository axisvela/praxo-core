from pathlib import Path
import json
import re
from urllib.parse import urljoin


ROOT = Path(__file__).resolve().parents[2]
REPOSITORY = "https://github.com/axisvela/praxo-core/blob/main/"
LEGACY_PATHS = {
    "00-overview.md": "getting-started/overview.md",
    "quickstart.md": "getting-started/quickstart.md",
    "adoption.md": "getting-started/adoption.md",
    "01-architecture.md": "reference/architecture.md",
    "02-primitives.md": "reference/primitives.md",
    "03-integration.md": "guides/integration.md",
    "04-license-and-provenance.md": "project/status/provenance.md",
    "05-compatibility.md": "project/status/version-compatibility.md",
    "06-roadmap.md": "project/planning/roadmap.md",
    "07-api-freeze.md": "project/status/api-stability.md",
    "08-security.md": "security/index.md",
    "09-release.md": "project/release/releasing.md",
    "10-plugin-authoring.md": "guides/plugins.md",
    "11-migration-v2.md": "project/release/migration-v2.md",
    "12-ecosystem.md": "integrations/ecosystem.md",
    "13-multi-agent.md": "guides/multi-agent.md",
    "14-workspace-session.md": "reference/workspace-session.md",
    "15-plugin-trust-sbom.md": "security/plugin-trust.md",
    "16-compatibility-policy.md": "project/status/compatibility-policy.md",
    "17-multilingual-sdk.md": "contributing/core-design.md",
    "contributing/sdk-design.md": "contributing/core-design.md",
    "18-multilingual-roadmap.md": "languages/support.md",
    "19-language-expansion.md": "contributing/language-policy.md",
    "adapters.md": "integrations/index.md",
    "benchmarks.md": "project/evaluation/benchmarks.md",
    "comparison.md": "project/evaluation/comparison.md",
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
LANGUAGE_PAGE_SLUGS = [
    page for page in MOVED_LANGUAGE_PAGES if page not in ("index", "support")
]
LEGACY_PATHS.update({
    f"sdks/{page}.md": f"languages/{page}/index.md"
    for page in LANGUAGE_PAGE_SLUGS
})
LEGACY_PATHS["sdks/index.md"] = "languages/index.md"
LEGACY_PATHS["sdks/support.md"] = "languages/support.md"
LEGACY_PATHS.update({
    "project/compatibility.md": "project/status/version-compatibility.md",
    "project/compatibility-policy.md": "project/status/compatibility-policy.md",
    "project/contract-status.md": "project/status/contract-status.md",
    "project/api-stability.md": "project/status/api-stability.md",
    "project/repository-layout.md": "project/status/repository-layout.md",
    "project/provenance.md": "project/status/provenance.md",
    "project/delivery-history.md": "project/status/delivery-history.md",
    "project/roadmap.md": "project/planning/roadmap.md",
    "project/execution-correctness.md": "project/planning/execution-correctness-model.md",
    "project/ai-native-reference-applications.md": "project/planning/ai-native-reference-applications.md",
    "project/embodied-pilot.md": "project/planning/embodied-pilot.md",
    "project/releasing.md": "project/release/releasing.md",
    "project/migration-v2.md": "project/release/migration-v2.md",
    "project/verification-evidence.md": "project/evaluation/verification-evidence.md",
    "project/execution-correctness-evidence.md": "project/evaluation/execution-correctness-evidence.md",
    "project/adoption-baseline.md": "project/evaluation/adoption-baseline.md",
    "project/benchmarks.md": "project/evaluation/benchmarks.md",
    "project/comparison.md": "project/evaluation/comparison.md",
    "project/test-taxonomy.md": "project/evaluation/test-and-evidence-taxonomy.md",
})


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
        if (ROOT / "docs/languages" / slug / "index.md").is_file():
            name = f"[{name}]({slug}/index.md)"
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
                      if page not in ("index", "support")
                      and not (ROOT / "docs/zh-CN/languages" / page / "index.md").exists()})
    redirects["zh-CN/sdks/index.md"] = urljoin(config.site_url, "zh-CN/languages/")
    redirects["zh-CN/sdks/support.md"] = urljoin(
        config.site_url, "zh-CN/languages/support/"
    )
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
    sources = {
        "go": ("go", {"main.go": "main.go", "main_test.go": "main_test.go"}),
        "python": ("python", {"starter.py": "starter.py", "test_starter.py": "test_starter.py"}),
        "typescript": ("javascript", {
            "starter.js": "starter.js",
            "test_starter.test.js": "test_starter.test.js",
        }),
        "java": ("java", {
            "App.java": "src/main/java/starter/App.java",
            "AppTest.java": "src/test/java/starter/AppTest.java",
        }),
        "ruby": ("ruby", {
            "starter.rb": "starter.rb",
            "test_starter.rb": "test_starter.rb",
        }),
        "php": ("php", {
            "starter.php": "starter.php",
            "test_starter.php": "test_starter.php",
        }),
        "elixir": ("elixir", {
            "starter.exs": "starter.exs",
            "test_starter.exs": "test_starter.exs",
        }),
        "lua": ("lua", {
            "starter.lua": "starter.lua",
            "test_starter.lua": "test_starter.lua",
        }),
    }
    for language, (syntax, filenames) in sources.items():
        for filename, relative in filenames.items():
            marker = "<!-- " + language + "-consumer-source: " + filename + " -->"
            if marker in markdown:
                if language == "go":
                    base = ROOT / "language" / "go" / "examples" / "consumer-go"
                else:
                    base = ROOT / "language" / language / "examples" / "consumer"
                source = (base / relative).read_text(encoding="utf-8")
                markdown = markdown.replace(marker, "```" + syntax + "\n" + source.rstrip() + "\n```")
    if "<!-- language-support-matrix -->" in markdown:
        source = (ROOT / "spec/languages.md").read_text(encoding="utf-8")
        markdown = markdown.replace("<!-- language-support-matrix -->", language_matrix(source, page.file.src_uri.startswith("zh-CN/")))
    source = page.meta.get("sdk_readme")
    if source:
        path = (ROOT / source).resolve()
        if not path.is_relative_to(ROOT) or path.name != "README.md":
            raise ValueError("Core documentation must reference a repository README.md")
        return markdown + "\n\n" + sdk_readme(path.read_text(encoding="utf-8"), source)
    return markdown


def on_post_page(output, page, config):
    if page.file.src_uri not in ("index.md", "zh-CN/index.md"):
        return output
    discovery = json.loads((ROOT / "language/discovery.json").read_text(encoding="utf-8"))
    data = {
        "@context": "https://schema.org",
        "@type": "SoftwareSourceCode",
        "name": "PRAXO-CORE",
        "alternateName": discovery["aliases"],
        "description": config["site_description"],
        "url": config["site_url"],
        "codeRepository": "https://github.com/axisvela/praxo-core",
        "license": "https://spdx.org/licenses/MIT.html",
        "keywords": discovery["topics"],
    }
    payload = json.dumps(data, ensure_ascii=True).replace("<", "\\u003c").replace(">", "\\u003e").replace("&", "\\u0026")
    return output.replace("</head>", f'<script type="application/ld+json">{payload}</script>\n</head>', 1)
