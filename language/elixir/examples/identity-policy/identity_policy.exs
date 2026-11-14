defmodule IdentityPolicyExample do
  def authorize(principal, action) do
    cond do
      principal == nil -> %{allowed: false, reason: "missing"}
      not principal.active -> %{allowed: false, reason: "inactive"}
      action.kind == "model.generate" -> %{allowed: true, reason: "model"}
      principal.role != "operator" -> %{allowed: false, reason: "role"}
      Map.get(action, :tenant) != principal.tenant -> %{allowed: false, reason: "tenant"}
      Map.get(action, :tool) != "record" -> %{allowed: false, reason: "operation"}
      true -> %{allowed: true, reason: "operator"}
    end
  end
end

operator = %{tenant: "acme", role: "operator", active: true}
true = IdentityPolicyExample.authorize(operator, %{kind: "model.generate"}).allowed
true = IdentityPolicyExample.authorize(operator, %{kind: "tool.invoke", tool: "record", tenant: "acme"}).allowed
false = IdentityPolicyExample.authorize(%{operator | role: "viewer"}, %{kind: "tool.invoke", tool: "record", tenant: "acme"}).allowed
false = IdentityPolicyExample.authorize(operator, %{kind: "tool.invoke", tool: "record", tenant: "other"}).allowed
false = IdentityPolicyExample.authorize(nil, %{kind: "model.generate"}).allowed
IO.puts("Elixir identity policy example passed")
