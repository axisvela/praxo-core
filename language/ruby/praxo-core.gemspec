Gem::Specification.new do |spec|
  spec.name = "praxo-core"
  spec.version = File.read(File.expand_path("VERSION", __dir__)).strip
  spec.authors = ["AxisVela"]
  spec.email = ["releases@axisvela.com"]

  spec.summary = "PRAXO-CORE (praxocore): embeddable, policy-governed AI agent framework for Ruby"
  spec.description = <<~DESC.strip
    PRAXO-CORE (praxocore) Ruby Core is a dependency-free, in-process agent framework for Ruby.

    Highlights:
    - Governed agent loop with tool registration, policy hooks, final-argument authorization, HITL approve/edit/reject/respond, and typed events.
    - Memory, context budgets, middleware, checkpoints, streaming, cancellation, bounded parallel tools, and run-scoped call limits.
    - OpenAI-compatible, Anthropic, and Gemini adapters; stdio MCP, OpenTelemetry, Harmovela, retriever, and synchronous delegation seams.
    - MIT-licensed embedding boundary; no hosted service, provider SDK, or production sandbox.

    Scenario tutorials: community-governance, due-diligence, finops-review, lead-nurture, recruiting-match, retail-replenishment, supply-chain-review, supply-disruption.

    Reference application: Rails commerce copilot (source implementation; acceptance pending).

    Examples, tutorials, reference applications, and community:
    https://github.com/axisvela/praxo-core-ruby
    Community: https://x.com/axisvela | https://github.com/axisvela/praxo-core/discussions | https://axisvela.github.io/praxo-core/
  DESC
  spec.homepage = "https://axisvela.github.io/praxo-core/"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.metadata = {
    "source_code_uri" => "https://github.com/axisvela/praxo-core-ruby",
    "bug_tracker_uri" => "https://github.com/axisvela/praxo-core-ruby/issues",
    "documentation_uri" => "https://axisvela.github.io/praxo-core/languages/ruby/"
  }

  spec.files = Dir["lib/**/*.rb", "api/**/*.txt", "LICENSE", "README.md",
                   "REGISTRY.md", "llms.txt", "llms.md"]
  spec.require_paths = ["lib"]
end
