Gem::Specification.new do |spec|
  spec.name = "praxo-core"
  spec.version = File.read(File.expand_path("VERSION", __dir__)).strip
  spec.authors = ["AxisVela"]
  spec.email = ["releases@axisvela.com"]

  spec.summary = "Embeddable, policy-governed AI agent framework for Ruby"
  spec.description = "Native Ruby Core for PRAXO-CORE: a dependency-free, in-process agent loop with governed tool calls, policy and HITL decisions, typed events, memory, context budgets, middleware, checkpoints, streaming OpenAI-compatible/Anthropic/Gemini adapters, MCP, OpenTelemetry, Harmovela, retriever, and synchronous delegation. Scenario tutorials and a Rails commerce reference application are available in the source repository. Examples, tutorials, reference applications, and community links: https://github.com/axisvela/praxo-core-ruby"
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
