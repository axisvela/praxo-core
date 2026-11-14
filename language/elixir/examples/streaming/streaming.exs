alias Praxo.{Agent, Models}

{:ok, collector} = Elixir.Agent.start_link(fn -> [] end)
options = %{
  Agent.new_agent_options(Agent.static_model("done")) |
    on_stream: fn part -> Elixir.Agent.update(collector, &(&1 ++ [part.kind])) end
}

{:ok, result, _options} = Agent.run_agent(options, Models.session("streaming"), "go")
parts = Elixir.Agent.get(collector, & &1)

unless result.output == "done" do
  raise "unexpected output: #{result.output}"
end

unless parts == ["values", "messages"] do
  raise "unexpected stream parts: #{inspect(parts)}"
end

IO.puts("Elixir streaming example passed")
