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
    "18-multilingual-roadmap.md": "sdks/support.md",
    "19-language-expansion.md": "contributing/language-policy.md",
    "adapters.md": "integrations/index.md",
    "benchmarks.md": "project/benchmarks.md",
    "comparison.md": "project/comparison.md",
    "containment-review.md": "security/containment.md",
    "documentation-index.md": "getting-started/index.md",
    "event-schema.md": "reference/events.md",
    "recipes.md": "guides/recipes.md",
    "sdks.md": "sdks/index.md",
}


def on_config(config):
    redirects = config.plugins["redirects"].config["redirect_maps"]
    redirects.update(LEGACY_PATHS)
    redirects.update({"zh-CN/" + old: "zh-CN/" + new
                      for old, new in LEGACY_PATHS.items()
                      if (ROOT / "docs/zh-CN" / new).exists()})
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
    source = page.meta.get("sdk_readme")
    if source:
        path = (ROOT / source).resolve()
        if not path.is_relative_to(ROOT) or path.name != "README.md":
            raise ValueError("SDK documentation must reference a repository README.md")
        return markdown + "\n\n" + sdk_readme(path.read_text(encoding="utf-8"), source)
    return markdown
