defmodule ProviderFallbackExample do
  def run(primary, fallback) do
    try do
      primary.()
    rescue
      primary_error ->
        try do
          fallback.()
        rescue
          _ -> reraise primary_error, __STACKTRACE__
        end
    end
  end
end

{:ok, fallback_calls} = Agent.start_link(fn -> 0 end)
ProviderFallbackExample.run(fn -> "primary" end, fn ->
  Agent.update(fallback_calls, &(&1 + 1))
  "fallback"
end)
0 = Agent.get(fallback_calls, & &1)

"fallback" = ProviderFallbackExample.run(
  fn -> raise "MODEL_UNAVAILABLE" end,
  fn -> "fallback" end
)

try do
  ProviderFallbackExample.run(
    fn -> raise "MODEL_UNAVAILABLE" end,
    fn -> raise "MODEL_UNAVAILABLE" end
  )
  raise "both-failure path did not reject"
rescue
  error in RuntimeError ->
    unless error.message == "MODEL_UNAVAILABLE" do
      reraise error, __STACKTRACE__
    end
end

IO.puts("Elixir provider fallback example passed")
