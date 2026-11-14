alias Praxo.{Agent, Models}

defmodule HitlExample do
  def run do
    {:ok, notes} = Elixir.Agent.start_link(fn -> [] end)

    model = Agent.scripted_model([
      Models.response(Models.message_assistant("", [
        Models.tool_call("write-note-1", "write_note", %{
          "text" => "hello",
          "visibility" => "public"
        })
      ])),
      Models.response(Models.message_assistant("done"))
    ])

    options = %{Agent.new_agent_options(model) |
      tools: [%Praxo.Tool{
        name: "write_note",
        description: "Write a short note with the requested visibility.",
        parameters: %{
          "type" => "object",
          "required" => ["text", "visibility"],
          "properties" => %{
            "text" => %{"type" => "string"},
            "visibility" => %{"type" => "string", "enum" => ["public", "private"]}
          }
        },
        invoke: fn arguments ->
          Elixir.Agent.update(notes, &(&1 ++ [arguments["text"]]))
          "written"
        end
      }],
      allowed_tools: ["write_note"],
      policy: fn action ->
        if action.kind == "tool.invoke" do
          Models.decision(
            action.tool_name == "write_note" and
              action.arguments["visibility"] == "public",
            "only public notes are permitted"
          )
        else
          Models.decision(true)
        end
      end,
      interrupt_on: ["write_note"],
      on_interrupt_decision: fn _interrupt ->
        %Praxo.InterruptDecision{action: "approve"}
      end}

    {:ok, result, _} = Agent.run_agent(options, Models.session("hitl-approve"), "Write a note.")
    unless result.output == "done" and length(Elixir.Agent.get(notes, & &1)) == 1 do
      raise "approve scenario failed"
    end
    IO.puts("approve: written; effects=1")

    model = Agent.scripted_model([
      Models.response(Models.message_assistant("", [
        Models.tool_call("write-note-1", "write_note", %{
          "text" => "hello",
          "visibility" => "public"
        })
      ])),
      Models.response(Models.message_assistant("done"))
    ])
    options = %{options | model: model,
      on_interrupt_decision: fn _interrupt ->
        %Praxo.InterruptDecision{
          action: "edit",
          arguments: %{"text" => "hello", "visibility" => "private"}
        }
      end}
    {:error, "AGENT_POLICY_DENIED", _} =
      Agent.run_agent(options, Models.session("hitl-edit"), "Write a note.")
    unless Elixir.Agent.get(notes, & &1) == ["hello"] do
      raise "edit scenario produced effects"
    end
    IO.puts("edit: policy rejected; effects=0")
  end
end

HitlExample.run()
