defmodule ServiceExample do
  def handle("GET", "/healthz", _principal, _body),
    do: {200, %{"status" => "ok"}}

  def handle(method, path, _principal, _body) when method != "POST" or path != "/run",
    do: {404, %{"error" => "not found"}}

  def handle("POST", "/run", principal, _body) when principal in [nil, ""],
    do: {401, %{"error" => "missing X-Praxo-Principal"}}

  def handle("POST", "/run", _principal, body) do
    if String.contains?(body, "\"prompt\"") do
      {200, %{"output" => "hello from the service"}}
    else
      {400, %{"error" => "prompt is required"}}
    end
  end
end

{200, %{"status" => "ok"}} = ServiceExample.handle("GET", "/healthz", nil, "")
{401, _} = ServiceExample.handle("POST", "/run", nil, ~s({"prompt":"hi"}))
{200, %{"output" => "hello from the service"}} =
  ServiceExample.handle("POST", "/run", "user-1", ~s({"prompt":"hi"}))
IO.puts("Elixir service example passed")
