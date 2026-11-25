defmodule PraxoOps.MixProject do
  use Mix.Project

  def project do
    [
      app: :praxo_ops,
      version: "0.0.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {PraxoOps.Application, []}
    ]
  end

  defp deps do
    case System.get_env("PRAXO_CORE_PATH") do
      nil -> [{:praxo_core, "~> 0.10.0"}]
      path -> [{:praxo_core, path: path}]
    end
  end
end
