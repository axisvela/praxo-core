defmodule PraxoConsumer.MixProject do
  use Mix.Project

  def project do
    [app: :praxo_consumer, version: "0.1.0", elixir: "~> 1.14", deps: deps()]
  end

  def application, do: [extra_applications: [:logger]]

  defp deps do
    [{:praxo_core, "~> 0.5.1"}]
  end
end
