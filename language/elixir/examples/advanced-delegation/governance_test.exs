defmodule Praxo.AdvancedDelegation.BudgetExhausted do
  defexception message: "delegation budget exhausted"
end

defmodule Praxo.AdvancedDelegation.DelegationError do
  defexception message: "delegation error"
end

defmodule Praxo.AdvancedDelegation.SharedBudget do
  def new(remaining) do
    {:ok, pid} = Elixir.Agent.start_link(fn -> remaining end)
    pid
  end

  def available?(budget), do: Elixir.Agent.get(budget, &(&1 > 0))

  def take(budget) do
    Elixir.Agent.get_and_update(budget, fn
      remaining when remaining > 0 -> {true, remaining - 1}
      remaining -> {false, remaining}
    end)
  end
end

defmodule Praxo.AdvancedDelegation.ComposedPolicy do
  def compose(nil, nil), do: nil
  def compose(parent, nil), do: parent
  def compose(nil, child), do: child

  def compose(parent, child) when is_function(parent, 1) and is_function(child, 1) do
    fn action ->
      case parent.(action) do
        %{allowed: true} -> child.(action)
        decision -> decision
      end
    end
  end
end

defmodule Praxo.AdvancedDelegation.ChildScope do
  alias Praxo.AdvancedDelegation.{BudgetExhausted, SharedBudget}

  defstruct authority: nil, release: nil

  def release(%__MODULE__{release: release}), do: release.()

  def run(%__MODULE__{} = scope, model, tools, prompt, opts \\ []) do
    names = scope.authority.allowed |> MapSet.to_list() |> Enum.sort()

    scoped =
      Enum.map(names, fn name ->
        inner = Enum.find(tools, fn tool -> tool.name == name end)
        budgeted_tool(inner, scope.authority.budget)
      end)

    options =
      %{
        Praxo.Agent.new_agent_options(model)
        | tools: scoped,
          max_steps: 3,
          allowed_tools: names,
          policy: scope.authority.policy,
          middleware: Keyword.get(opts, :middleware, []),
          cancellation: Keyword.get(opts, :cancellation, nil),
          require_policy: true,
          require_tool_scope: true
      }

    Praxo.Agent.run_agent(
      options,
      Praxo.Models.session("governed-delegation-child"),
      prompt
    )
  end

  defp budgeted_tool(inner, budget) do
    Praxo.Agent.new_tool(inner.name, inner.description, fn arguments ->
      unless SharedBudget.take(budget), do: raise(BudgetExhausted)
      inner.invoke.(arguments)
    end)
  end
end

defmodule Praxo.AdvancedDelegation.Governor do
  alias Praxo.AdvancedDelegation.{
    BudgetExhausted,
    ChildScope,
    ComposedPolicy,
    DelegationError,
    SharedBudget
  }

  defstruct authority: nil, active: nil

  def new(authority) do
    %__MODULE__{authority: authority, active: :atomics.new(1, [])}
  end

  def delegate(%__MODULE__{} = governor, allowed, delegable \\ [], policy \\ nil) do
    authority = governor.authority
    allowed_set = MapSet.new(allowed)
    delegable_set = MapSet.new(delegable)

    cond do
      authority.depth + 1 > authority.max_depth ->
        raise DelegationError, "delegation depth exceeded"

      MapSet.size(allowed_set) == 0 ->
        raise DelegationError, "delegation tool scope is empty"

      not MapSet.subset?(allowed_set, authority.delegable) ->
        raise DelegationError, "delegation scope exceeds parent"

      not MapSet.subset?(allowed_set, authority.allowed) ->
        raise DelegationError, "delegation scope exceeds parent"

      not MapSet.subset?(delegable_set, authority.delegable) ->
        raise DelegationError, "child delegable scope exceeds parent"

      not SharedBudget.available?(authority.budget) ->
        raise BudgetExhausted

      true ->
        :ok
    end

    active = :atomics.get(governor.active, 1)

    if active >= authority.max_children do
      raise DelegationError, "delegation child limit exceeded"
    end

    :atomics.put(governor.active, 1, active + 1)
    released = :atomics.new(1, [])

    release = fn ->
      if :atomics.get(released, 1) == 0 do
        :atomics.put(released, 1, 1)
        :atomics.sub(governor.active, 1, 1)
      end

      :ok
    end

    child_authority = %{
      authority
      | allowed: allowed_set,
        delegable: delegable_set,
        depth: authority.depth + 1,
        policy: ComposedPolicy.compose(authority.policy, policy)
    }

    %ChildScope{authority: child_authority, release: release}
  end
end

defmodule Praxo.AdvancedDelegation.GovernanceTest do
  alias Praxo.AdvancedDelegation.{
    BudgetExhausted,
    ChildScope,
    DelegationError,
    Governor,
    SharedBudget
  }

  alias Praxo.{Agent, Models}

  def run do
    test_scope_escalation()
    test_depth_limit()
    test_child_limit()
    test_sibling_budget()
    test_cancellation()
    test_final_arguments()
    IO.puts("Elixir governance delegation checks passed (6)")
  end

  defp check(true, _message), do: :ok
  defp check(false, message), do: raise(message)

  defp allow_all(_action), do: Models.decision(true, "root")

  defp record_policy(action) do
    if action.kind != "tool.invoke" do
      Models.decision(true, "non-tool action")
    else
      cond do
        action.tool_name != "record" ->
          Models.decision(false, "child may only record")

        Map.get(action.arguments, "target") == "blocked" ->
          Models.decision(false, "blocked target")

        true ->
          Models.decision(true, "record allowed")
      end
    end
  end

  defp authority(allowed, delegable, max_depth, max_children, opts) do
    %{
      allowed: MapSet.new(allowed),
      delegable: MapSet.new(delegable),
      max_depth: max_depth,
      max_children: max_children,
      depth: Keyword.get(opts, :depth, 0),
      budget: Keyword.get(opts, :budget, SharedBudget.new(1)),
      policy: Keyword.get(opts, :policy, nil)
    }
  end

  defp fixture_model(tool_name, arguments, final, on_generate \\ nil) do
    fn request ->
      if is_function(on_generate, 0), do: on_generate.()
      last = List.last(request.messages)

      if last.role == "tool" do
        {:ok, Models.response(Models.message_assistant(final))}
      else
        {:ok,
         Models.response(
           Models.message_assistant("", [
             Models.tool_call("call-1", tool_name, arguments)
           ])
         )}
      end
    end
  end

  defp record_tool do
    ref = :atomics.new(1, [])

    tool =
      Agent.new_tool("record", "Record a delegated effect.", fn _arguments ->
        :atomics.add(ref, 1, 1)
        "recorded"
      end)

    {tool, fn -> :atomics.get(ref, 1) end}
  end

  defp parent_only_tool do
    ref = :atomics.new(1, [])

    tool =
      Agent.new_tool("parent_only", "Outside the child scope.", fn _arguments ->
        :atomics.add(ref, 1, 1)
        "parent-effect"
      end)

    {tool, fn -> :atomics.get(ref, 1) end}
  end

  defp catch_exception(fun) do
    try do
      fun.()
      :no_error
    rescue
      error -> error
    end
  end

  defp test_scope_escalation do
    {_record, record_calls} = record_tool()
    {_parent_only, parent_calls} = parent_only_tool()

    root =
      Governor.new(
        authority(["record", "parent_only"], ["record"], 1, 2,
          budget: SharedBudget.new(2),
          policy: &allow_all/1
        )
      )

    error = catch_exception(fn -> Governor.delegate(root, ["parent_only"]) end)
    check(match?(%DelegationError{}, error), "scope escalation was not rejected")
    check(record_calls.() == 0 and parent_calls.() == 0, "scope escalation produced effects")

    child = Governor.delegate(root, ["record"], [], &record_policy/1)
    ChildScope.release(child)
  end

  defp test_depth_limit do
    root =
      Governor.new(
        authority(["record"], ["record"], 1, 1,
          budget: SharedBudget.new(2),
          policy: &allow_all/1
        )
      )

    child = Governor.delegate(root, ["record"], [], &record_policy/1)
    grand = Governor.new(child.authority)

    error =
      catch_exception(fn ->
        Governor.delegate(grand, ["record"], [], &record_policy/1)
      end)

    check(match?(%DelegationError{}, error), "grandchild depth was not rejected")
    ChildScope.release(child)
  end

  defp test_child_limit do
    root =
      Governor.new(
        authority(["record"], ["record"], 1, 1,
          budget: SharedBudget.new(2),
          policy: &allow_all/1
        )
      )

    first = Governor.delegate(root, ["record"], [], &record_policy/1)
    error = catch_exception(fn -> Governor.delegate(root, ["record"]) end)
    check(match?(%DelegationError{}, error), "child count limit was not enforced")
    ChildScope.release(first)

    second = Governor.delegate(root, ["record"], [], &record_policy/1)
    ChildScope.release(second)
  end

  defp test_sibling_budget do
    {record, record_calls} = record_tool()
    tools = [record]

    root =
      Governor.new(
        authority(["record"], ["record"], 1, 2,
          budget: SharedBudget.new(1),
          policy: &allow_all/1
        )
      )

    first = Governor.delegate(root, ["record"], [], &record_policy/1)
    second = Governor.delegate(root, ["record"], [], &record_policy/1)

    {:ok, _result, _options} =
      ChildScope.run(
        first,
        fixture_model("record", %{"target" => "first"}, "first-done"),
        tools,
        "record once"
      )

    error =
      catch_exception(fn ->
        ChildScope.run(
          second,
          fixture_model("record", %{"target" => "second"}, "second-done"),
          tools,
          "record twice"
        )
      end)

    check(match?(%BudgetExhausted{}, error), "sibling budget was not shared")
    check(record_calls.() == 1, "sibling budget effect count was not one")
    ChildScope.release(first)
    ChildScope.release(second)
  end

  defp test_cancellation do
    {record, record_calls} = record_tool()
    ref = :atomics.new(1, [])

    root =
      Governor.new(
        authority(["record"], ["record"], 1, 1,
          budget: SharedBudget.new(1),
          policy: &allow_all/1
        )
      )

    child = Governor.delegate(root, ["record"], [], &record_policy/1)

    model =
      fixture_model("record", %{"target" => "safe"}, "unexpected", fn ->
        :atomics.put(ref, 1, 1)
      end)

    result =
      ChildScope.run(child, model, [record], "cancel before effect",
        cancellation: fn -> :atomics.get(ref, 1) == 1 end
      )

    check(match?({:error, "AGENT_CANCELLED", _}, result), "cancellation did not stop the child run")
    check(record_calls.() == 0, "cancellation produced an effect")
    ChildScope.release(child)
  end

  defp test_final_arguments do
    {record, record_calls} = record_tool()

    root =
      Governor.new(
        authority(["record"], ["record"], 1, 1,
          budget: SharedBudget.new(1),
          policy: &allow_all/1
        )
      )

    child = Governor.delegate(root, ["record"], [], &record_policy/1)

    middleware = [
      %{
        before_tool: fn call ->
          %{call | arguments: Map.put(call.arguments, "target", "blocked")}
        end
      }
    ]

    result =
      ChildScope.run(
        child,
        fixture_model("record", %{"target" => "safe"}, "unexpected"),
        [record],
        "record safely",
        middleware: middleware
      )

    check(
      match?({:error, "AGENT_POLICY_DENIED", _}, result),
      "final argument reauthorization did not fail"
    )

    check(record_calls.() == 0, "final argument produced an effect")
    ChildScope.release(child)
  end
end

Praxo.AdvancedDelegation.GovernanceTest.run()
