alias Praxo.Middleware

schema = %{
  "type" => "object",
  "required" => ["name"],
  "properties" => %{"name" => %{"type" => "string"}}
}

config = Middleware.structured_output(schema, 0)
{:ok, ~s({"name":"ok"})} = Middleware.apply_structured(config, ~s({"name":"ok"}))
{:error, "AGENT_STRUCTURED_OUTPUT"} = Middleware.apply_structured(config, "{}")
IO.puts("Elixir structured output example passed")
