defmodule Praxo.MixProject do
  use Mix.Project

  def project do
    [
      app: :praxo_core,
      version: "0.1.1",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      description: "Embeddable MIT-licensed agent framework for Elixir",
      package: package(),
      deps: []
    ]
  end

  def application do
    [extra_applications: []]
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/axisvela/praxo-core"},
      files: ~w(lib api README.md LICENSE mix.exs)
    ]
  end
end
