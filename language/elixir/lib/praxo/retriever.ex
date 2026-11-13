defmodule Praxo.Document do
  defstruct id: "", content: "", metadata: %{}, score: 0.0

  def wire(%__MODULE__{} = document) do
    out = %{"id" => document.id, "content" => document.content}

    out =
      if document.metadata == %{},
        do: out,
        else: Map.put(out, "metadata", document.metadata)

    if document.score == 0.0,
      do: out,
      else: Map.put(out, "score", document.score)
  end
end

defmodule Praxo.FuncRetriever do
  defstruct retrieve: nil

  def new(retrieve) when is_function(retrieve, 2), do: %__MODULE__{retrieve: retrieve}

  def retrieve(%__MODULE__{retrieve: retrieve}, query, limit),
    do: retrieve.(query, limit)
end
