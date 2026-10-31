Gem::Specification.new do |spec|
  spec.name = "praxo-core"
  spec.version = File.read(File.expand_path("VERSION", __dir__)).strip
  spec.authors = ["AxisVela"]
  spec.email = ["releases@axisvela.com"]

  spec.summary = "Embeddable MIT-licensed agent framework for Ruby"
  spec.description = "Native Ruby Core for the PRAXO-CORE agent framework: tools, policy, events, memory, context, middleware, checkpoints, and an agent loop."
  spec.homepage = "https://axisvela.github.io/praxo-core/"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.metadata = {
    "source_code_uri" => "https://github.com/axisvela/praxo-core",
    "bug_tracker_uri" => "https://github.com/axisvela/praxo-core/issues",
    "documentation_uri" => "https://axisvela.github.io/praxo-core/languages/ruby/"
  }

  spec.files = Dir["lib/**/*.rb", "api/**/*.txt", "LICENSE", "README.md"]
  spec.require_paths = ["lib"]
end
