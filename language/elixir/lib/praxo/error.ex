defmodule Praxo.Error do
  defexception [:code, :message]

  @impl true
  def message(%{message: message}), do: message
end
