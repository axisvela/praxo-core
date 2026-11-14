alias Praxo.CheckpointAllowlist

allow =
  CheckpointAllowlist.new()
  |> CheckpointAllowlist.register("order")

{:ok, encoded} = CheckpointAllowlist.marshal(allow, "order", %{"value" => "x"})
{:ok, decoded} = CheckpointAllowlist.unmarshal(allow, encoded)

unless decoded == %{"value" => "x"} do
  raise "checkpoint payload did not round trip"
end

case CheckpointAllowlist.marshal(allow, "missing", %{}) do
  {:error, "CHECKPOINT_TYPE_NOT_ALLOWED"} ->
    IO.puts("Elixir checkpoint example passed")

  other ->
    raise "unexpected unregistered result: #{inspect(other)}"
end
