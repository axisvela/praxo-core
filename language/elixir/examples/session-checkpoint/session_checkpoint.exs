alias Praxo.{Agent, CheckpointAllowlist, Models}

allow =
  CheckpointAllowlist.new()
  |> CheckpointAllowlist.register("session")

session = Models.session("session-1", [
  Models.message("user", "first"),
  Models.message("assistant", "ack")
])

payload =
  CheckpointAllowlist.marshal(allow, "session", %{
    "messages" => Enum.map(session.messages, &Models.message_wire/1)
  })
  |> elem(1)

restored = CheckpointAllowlist.unmarshal(allow, payload) |> elem(1)
messages =
  Enum.map(restored["messages"], fn item ->
    Models.message(item["role"], item["content"] || "")
  end)

session = %{session | messages: messages}
model = fn request ->
  {:ok, Models.response(Models.message_assistant("turn #{length(request.messages)}"))}
end
{:ok, result, _} = Agent.run_agent(Agent.new_agent_options(model), session, "second")
unless result.output == "turn 3", do: raise("unexpected second turn")

session = %{session | messages: session.messages ++ [
  Models.message("user", "second"),
  Models.message("assistant", result.output)
]}
payload =
  CheckpointAllowlist.marshal(allow, "session", %{
    "messages" => Enum.map(session.messages, &Models.message_wire/1)
  })
  |> elem(1)

restored = CheckpointAllowlist.unmarshal(allow, payload) |> elem(1)
messages =
  Enum.map(restored["messages"], fn item ->
    Models.message(item["role"], item["content"] || "")
  end)

session = %{session | messages: messages}
{:ok, result, _} = Agent.run_agent(Agent.new_agent_options(model), session, "third")
unless result.output == "turn 5", do: raise("unexpected third turn")

IO.puts("restored messages: #{length(session.messages)}")
IO.puts("output: #{result.output}")
