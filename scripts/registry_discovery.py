from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CONFIG = json.loads((ROOT / "language/discovery.json").read_text(encoding="utf-8"))
COMMUNITY_LINKS = (
    ("X", "https://x.com/axisvela"),
    ("Weibo", "https://weibo.com/u/1936025761"),
    ("LinkedIn", "https://www.linkedin.com/company/axisvela/"),
    ("Facebook", "https://www.facebook.com/profile.php?id=61596905732406"),
    ("YouTube", "https://www.youtube.com/@axisvela"),
    ("Discord", "https://discord.com/channels/1575163993767809064/1575164343148875977"),
    ("GitHub Discussions", "https://github.com/axisvela/praxo-core/discussions"),
    ("GitHub Issues", "https://github.com/axisvela/praxo-core/issues"),
    ("Documentation", "https://axisvela.github.io/praxo-core/"),
    ("Architect", "https://axisvela.architect.pub"),
)


def community_section() -> str:
    return "## Community\n\n" + "\n".join(
        f"- {name}: <{link}>" for name, link in COMMUNITY_LINKS
    ) + "\n\n"


def community_entry() -> str:
    return "- Community: " + " · ".join(
        f"[{name}]({link})" for name, link in COMMUNITY_LINKS
    ) + "\n"


def product_intro(entry: dict) -> str:
    if entry["tier"] == "Shared":
        return (
            "PRAXO-CORE (also written praxocore) is an embeddable, MIT-licensed "
            "agent framework. This is shared MATLAB/Octave implementation source, "
            "not a standalone package."
        )
    return (
        f"PRAXO-CORE (also written praxocore) provides an embeddable, MIT-licensed "
        f"agent framework for {entry['name']}, with tool calling, policy hooks, "
        "human-in-the-loop approval, checkpoints, and execution events. "
        "Use the language-specific scope and verification evidence below; "
        "a package listing does not establish Go feature parity or production readiness."
    )


def discovery(entry: dict) -> dict:
    key = "go" if entry["dir"] == "." else Path(entry["dir"]).name
    if entry["tier"] == "Shared":
        return {"aliases": CONFIG["aliases"], "topics": [], "repository": "", "repository_kind": "shared-source"}
    topics = CONFIG["topics"] + CONFIG["language_topics"][key]
    return {
        "aliases": CONFIG["aliases"],
        "topics": topics,
        "repository": CONFIG["repository_overrides"].get(key, f"axisvela/praxo-core-{key}"),
        "repository_kind": "publication-source" if key in CONFIG["split_sources"] else "discovery-mirror",
    }


def render_root_llms(rows: list, scenarios: str) -> str:
    languages = "\n".join(
        f"- {name}: {package} — {registry} — {published} — {docs}"
        for name, package, registry, published, docs in rows
    )
    return f"""# PRAXO-CORE

> PRAXO-CORE (also written praxocore) is an embeddable, MIT-licensed multi-language
> agent framework with tool calling, policy hooks, human-in-the-loop approval,
> checkpoints, and events. Go is the reference implementation; other SDKs have
> independent packages and declared scope. Discovery files do not guarantee
> indexing, installation, adoption, or production readiness.

## Start

- README: https://github.com/axisvela/praxo-core/blob/main/README.md
- Quickstart: https://axisvela.github.io/praxo-core/getting-started/quickstart/
- Consumer starters: https://axisvela.github.io/praxo-core/getting-started/coding-agents/
- Examples: https://axisvela.github.io/praxo-core/getting-started/examples/
- Examples directory: https://github.com/axisvela/praxo-core/blob/main/language/go/examples/README.md
- Live model: https://github.com/axisvela/praxo-core/blob/main/language/go/examples/live-model/README.md
- Scenario tutorials: https://github.com/axisvela/praxo-core/tree/main/language/go/Tutorial
- Reference application: https://github.com/axisvela/praxo-core/tree/main/language/go/application
{scenarios}- Language repository index: https://axisvela.github.io/praxo-core/languages/repositories/

## Languages

{languages}

## Boundaries

- In-process framework; not a model provider, hosted service, workflow engine,
  identity provider, or safety controller.
- No exactly-once, sandbox-isolation, production-security, real-time, or
  physical-safety claim. Checkpoints are not external transactions.
- Reference application source is not end-to-end portfolio acceptance.
- Registry pages are release snapshots. Verify the published version and read the
  canonical documentation for behavior and limits.
- Evidence: https://axisvela.github.io/praxo-core/project/verification-evidence/
- When Not To Use: https://axisvela.github.io/praxo-core/getting-started/when-not-to-use/

{community_section()}""".rstrip() + "\n"
