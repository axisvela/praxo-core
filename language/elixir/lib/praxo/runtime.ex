defmodule Praxo.Sink do
  defstruct kinds: [], mode: :record, predicate: [], target: nil, sinks: []

  def new, do: %__MODULE__{}

  def multi(sinks), do: %__MODULE__{mode: :multi, sinks: sinks}

  def filter(target, predicate), do: %__MODULE__{mode: :filter, target: target, predicate: predicate}

  def emit(%__MODULE__{mode: :multi, sinks: sinks} = sink, event) do
    %{sink | sinks: Enum.map(sinks, &emit(&1, event))}
  end

  def emit(%__MODULE__{mode: :filter} = sink, event) do
    if sink.predicate == [] or event.kind in sink.predicate do
      %{sink | target: emit(sink.target, event)}
    else
      sink
    end
  end

  def emit(sink, event), do: %{sink | kinds: sink.kinds ++ [event.kind]}
end

defmodule Praxo.MemoryStore do
  defstruct records: %{}, sequence: 0

  def new, do: %__MODULE__{}

  def put(store, session_id, record) do
    {record, sequence} =
      if record.id == "" do
        {%{record | id: "mem-#{System.system_time(:second)}-#{store.sequence}"}, store.sequence + 1}
      else
        {record, store.sequence}
      end

    record =
      if record.created_at == nil do
        %{record | created_at: Integer.to_string(System.system_time(:second))}
      else
        record
      end

    records = Map.update(store.records, session_id, [record], &(&1 ++ [record]))
    {%{store | records: records, sequence: sequence}, record}
  end

  def search(store, session_id, query, limit) do
    needle = String.downcase(String.trim(query))

    matches =
      store.records
      |> Map.get(session_id, [])
      |> Enum.filter(fn record ->
        needle == "" or String.contains?(String.downcase(record.content), needle)
      end)
      |> Enum.sort_by(& &1.created_at, :desc)

    if limit > 0, do: Enum.take(matches, limit), else: matches
  end
end

defmodule Praxo.CheckpointAllowlist do
  defstruct registered: MapSet.new()

  def new, do: %__MODULE__{}

  def register(allow, kind) do
    if kind == "" do
      raise Praxo.Error, code: "CHECKPOINT_ERROR", message: "checkpoint: type is required"
    end

    %{allow | registered: MapSet.put(allow.registered, kind)}
  end

  def marshal(allow, kind, value) do
    if MapSet.member?(allow.registered, kind) do
      {:ok, Praxo.Json.encode(%{"type" => kind, "data" => value})}
    else
      {:error, "CHECKPOINT_TYPE_NOT_ALLOWED"}
    end
  end

  def unmarshal(allow, data) do
    case Praxo.Json.parse(data) do
      {:ok, envelope} when is_map(envelope) ->
        type = Praxo.Json.get_string(envelope, "type") || ""

        if MapSet.member?(allow.registered, type) do
          {:ok, Map.get(envelope, "data", :null)}
        else
          {:error, "CHECKPOINT_TYPE_NOT_ALLOWED"}
        end

      _ ->
        {:error, "CHECKPOINT_ERROR"}
    end
  end
end

defmodule Praxo.PathChecker do
  defstruct grants: []
end

defmodule Praxo.Runtime do
  alias Praxo.{ContextBudget, Decision, PathChecker, PathGrant}

  def normalize_path(value) do
    path = String.replace(value, "\\", "/")

    {prefix, body, absolute} =
      cond do
        byte_size(path) >= 2 and String.at(path, 1) == ":" ->
          body = String.slice(path, 2..-1//1)
          absolute = String.starts_with?(body, "/")
          {String.slice(path, 0, 2) <> if(absolute, do: "/", else: ""), body, absolute}

        String.starts_with?(path, "/") ->
          {"/", path, true}

        true ->
          {"", path, false}
      end

    parts =
      body
      |> String.split("/")
      |> Enum.reduce([], fn
        "", acc -> acc
        ".", acc -> acc
        "..", [] -> if absolute, do: [], else: [".."]
        "..", [".." | _] = acc -> [".." | acc]
        "..", [_ | rest] -> rest
        part, acc -> [part | acc]
      end)
      |> Enum.reverse()

    result = prefix <> Enum.join(parts, "/")

    case :os.type() do
      {:win32, _} -> String.downcase(result)
      _ -> result
    end
  end

  def path_checker(grants) do
    normalized =
      Enum.map(grants, fn grant ->
        cond do
          grant.root == "" ->
            raise Praxo.Error, code: "POLICY_ERROR", message: "policy: path grant root is required"

          grant.access not in ["read", "write", "readwrite"] ->
            raise Praxo.Error, code: "POLICY_ERROR", message: "policy: invalid grant access"

          true ->
            %PathGrant{root: normalize_path(grant.root), access: grant.access}
        end
      end)

    %PathChecker{grants: normalized}
  end

  def check(%PathChecker{grants: grants}, target, need) do
    if need not in ["read", "write", "readwrite"] do
      raise Praxo.Error, code: "POLICY_ERROR", message: "policy: invalid requested access"
    end

    if grants == [] do
      %Decision{allowed: false, reason: "no allowed roots"}
    else
      resolved = normalize_path(target)

      matched =
        Enum.find(grants, fn grant ->
          path_within?(grant.root, resolved) and access_allows?(grant.access, need)
        end)

      cond do
        matched != nil ->
          %Decision{allowed: true, reason: "allowed"}

        Enum.any?(grants, &path_within?(&1.root, resolved)) ->
          %Decision{allowed: false, reason: "insufficient grant"}

        true ->
          %Decision{allowed: false, reason: "outside roots"}
      end
    end
  end

  def path_allowed(checker, target, need) do
    try do
      check(checker, target, need).allowed
    rescue
      Praxo.Error -> false
    end
  end

  defp path_within?(root, target) do
    root == target or String.starts_with?(target, root <> "/")
  end

  defp access_allows?("readwrite", _), do: true
  defp access_allows?("read", "read"), do: true
  defp access_allows?("write", "write"), do: true
  defp access_allows?(_, _), do: false

  def estimate_tokens(messages) do
    Enum.reduce(messages, 0, fn item, total ->
      total =
        total + 4 + div(byte_size(item.content), 4) +
          div(byte_size(item.tool_id || ""), 4)

      total =
        Enum.reduce(item.content_blocks, total, fn block, acc ->
          acc + 4 + div(byte_size(block.text || ""), 4)
        end)

      Enum.reduce(item.tool_calls, total, fn call, acc ->
        acc + 4 + div(byte_size(call.name), 4) +
          div(byte_size(Praxo.Json.encode(call.arguments)), 4)
      end)
    end)
  end

  def truncate_to_tokens(value, tokens) do
    if tokens <= 0 do
      ""
    else
      limit = tokens * 4

      cond do
        byte_size(value) <= limit -> value
        limit <= 16 -> binary_part(value, 0, limit)
        true -> binary_part(value, 0, limit - 16) <> "\n[truncated]"
      end
    end
  end

  def compact_context(%ContextBudget{} = budget, messages) do
    if budget.max_tokens <= 0 or estimate_tokens(messages) <= budget.max_tokens do
      {messages, true}
    else
      {system, rest} = Enum.split_with(messages, &(&1.role == "system"))

      system =
        Enum.reject(system, fn item ->
          String.starts_with?(item.content, "[context compacted:")
        end)

      case fit_system(system, budget.max_tokens) do
        {:error, _} ->
          {[], false}

        {:ok, system} ->
          keep = if budget.keep_recent > 0, do: budget.keep_recent, else: 4
          start = align_start(rest, max(length(rest) - keep, 0))
          marker = Praxo.Models.message("system", "[context compacted: #{start} older messages omitted]")
          kept = Enum.drop(rest, start)
          output = system ++ if(start > 0, do: [marker], else: []) ++ kept
          {kept, ok} = shrink(output, kept, system, marker, start, budget.max_tokens)
          {kept, ok}
      end
    end
  end

  defp fit_system([], _max), do: {:ok, []}

  defp fit_system(system, max) do
    if estimate_tokens(system) > max do
      [first | _] = system
      content = truncate_to_tokens(first.content, max - 4)
      trimmed = [%{first | content: content}]

      if estimate_tokens(trimmed) > max do
        {:error, :too_large}
      else
        {:ok, trimmed}
      end
    else
      {:ok, system}
    end
  end

  defp align_start(_rest, 0), do: 0

  defp align_start(rest, start) do
    if Enum.at(rest, start).role == "tool" do
      align_start(rest, start - 1)
    else
      start
    end
  end

  defp shrink(output, kept, system, marker, start, max) do
    if estimate_tokens(output) > max and length(kept) > 1 do
      if Enum.at(kept, 1).role == "tool" do
        {output, false}
      else
        kept = tl(kept)
        output = system ++ if(start > 0, do: [marker], else: []) ++ kept
        shrink(output, kept, system, marker, start, max)
      end
    else
      {output, estimate_tokens(output) <= max}
    end
  end

  def multi_sink(sinks), do: Praxo.Sink.multi(sinks)
  def filter_sink(target, predicate), do: Praxo.Sink.filter(target, predicate)

  def new_memory_store, do: Praxo.MemoryStore.new()

  def new_checkpoint_allowlist, do: Praxo.CheckpointAllowlist.new()

  def stream_kinds, do: Praxo.Models.stream_kinds()
end
