defmodule Praxo.MixProject do
  use Mix.Project

  def project do
    [
      app: :praxo_core,
      version: "0.4.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      description: "Embeddable MIT-licensed agent framework for Elixir",
      package: package(),
      docs: docs(),
      deps: deps()
    ]
  end

  def application do
    [extra_applications: []]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/axisvela/praxo-core"},
      files: ~w(lib api README.md CHANGELOG.md PUBLISHING.md LICENSE mix.exs)
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md",
        "CHANGELOG.md",
        "PUBLISHING.md",
        "SETUP.md",
        "LICENSE",
        "api/0.4.0.txt"
      ],
      skip_undefined_reference_warnings_on: ["README.md"]
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end
end
