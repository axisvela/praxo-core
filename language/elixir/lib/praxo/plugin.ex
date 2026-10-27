defmodule Praxo.Manifest do
  defstruct schema_version: 1,
            id: "",
            version: "",
            kind: "",
            entrypoint: %{},
            protocol: "",
            capabilities: [],
            permissions: %{},
            limits: %{},
            isolation: "",
            health: %{}
end

defmodule Praxo.Plugin do
  alias Praxo.{Json, Manifest}

  @known_kinds [
    "tool.provider.v1",
    "model.provider.v1",
    "policy.provider.v1",
    "memory.provider.v1",
    "sandbox.provider.v1"
  ]

  @manifest_keys [
    "schemaVersion",
    "id",
    "version",
    "kind",
    "entrypoint",
    "protocol",
    "capabilities",
    "permissions",
    "limits",
    "isolation",
    "health",
    "signature",
    "sbom"
  ]

  @entrypoint_keys ["type", "command", "module", "image", "args", "dir"]
  @permission_keys ["filesystem", "network", "env"]
  @limit_keys ["memoryMB", "cpuMillis", "timeoutMs", "maxInflight"]
  @health_keys ["method", "intervalMs"]
  @signature_keys ["algorithm", "keyId"]

  def parse_manifest(raw) when is_binary(raw) do
    try do
      {:ok, do_parse(raw)}
    rescue
      error in Praxo.Error -> {:error, error.code}
    end
  end

  defp do_parse(raw) do
    if String.trim(raw) == "" do
      fail("plugin: manifest is empty")
    end

    root =
      case Json.parse(raw) do
        {:ok, value} when is_map(value) -> value
        _ -> fail("plugin: manifest must be an object")
      end

    check_keys(root, @manifest_keys, "manifest")
    schema_version = integer_field(Json.get(root, "schemaVersion"), "schemaVersion")

    if schema_version != 1 do
      fail("plugin: manifest: schemaVersion = #{schema_version}, want 1")
    end

    id = string_field(Json.get(root, "id"), "id")
    if not valid_reverse_dns?(id), do: fail("plugin: manifest: id #{id} is not reverse-DNS")

    version = string_field(Json.get(root, "version"), "version")
    if not valid_semver?(version), do: fail("plugin: manifest: version #{version} is not semver")

    kind = string_field(Json.get(root, "kind"), "kind")
    if kind not in @known_kinds, do: fail("plugin: manifest: kind #{kind} is not a known contract")

    protocol = string_field(Json.get(root, "protocol"), "protocol")
    if protocol != "jsonrpc-2", do: fail("plugin: manifest: protocol = #{protocol}, want jsonrpc-2")

    entrypoint = object_field(Json.get(root, "entrypoint"), "entrypoint")
    check_keys(entrypoint, @entrypoint_keys, "entrypoint")
    entry_type = string_field(Json.get(entrypoint, "type"), "entrypoint.type")

    required =
      case entry_type do
        "process" -> "command"
        "wasm" -> "module"
        "container" -> "image"
        _ -> fail("plugin: manifest: unknown entrypoint type #{entry_type}")
      end

    if not text_present?(Json.get(entrypoint, required)) do
      fail("plugin: manifest: #{entry_type} entrypoint requires #{required}")
    end

    isolation = string_field(Json.get(root, "isolation"), "isolation")

    if isolation != entry_type do
      fail("plugin: manifest: isolation #{isolation} does not match entrypoint #{entry_type}")
    end

    permissions = object_field(Json.get(root, "permissions"), "permissions")
    check_keys(permissions, @permission_keys, "permissions")
    limits = object_field(Json.get(root, "limits"), "limits")
    check_keys(limits, @limit_keys, "limits")

    Enum.each(limits, fn {key, value} ->
      if integer_field(value, "limits.#{key}") < 0 do
        fail("plugin: manifest: limits must not be negative")
      end
    end)

    health = object_field(Json.get(root, "health"), "health")
    check_keys(health, @health_keys, "health")

    case Json.get(root, "signature") do
      nil ->
        :ok

      :null ->
        :ok

      signature ->
        signature = object_field(signature, "signature")
        check_keys(signature, @signature_keys, "signature")

        if not text_present?(Json.get(signature, "algorithm")) or
             not text_present?(Json.get(signature, "keyId")) do
          fail("plugin: manifest: signature requires algorithm and keyId")
        end
    end

    capabilities =
      case Json.get(root, "capabilities") do
        nil ->
          []

        :null ->
          []

        value when is_list(value) ->
          Enum.reduce(value, [], fn item, acc ->
            capability = string_field(item, "capabilities")

            cond do
              capability == "" -> fail("plugin: manifest: capability must not be empty")
              capability in acc -> fail("plugin: manifest: duplicate capability")
              true -> acc ++ [capability]
            end
          end)

        _ ->
          fail("plugin: manifest: capabilities must be an array")
      end

    %Manifest{
      schema_version: schema_version,
      id: id,
      version: version,
      kind: kind,
      entrypoint: entrypoint,
      protocol: protocol,
      capabilities: capabilities,
      permissions: permissions,
      limits: limits,
      isolation: isolation,
      health: health
    }
  end

  defp fail(message), do: raise(Praxo.Error, code: "PLUGIN_INVALID", message: message)

  defp check_keys(value, allowed, where) when is_map(value) do
    Enum.each(Map.keys(value), fn key ->
      if key not in allowed do
        fail("plugin: manifest: unknown field #{key} in #{where}")
      end
    end)
  end

  defp object_field(nil, _where), do: %{}
  defp object_field(:null, _where), do: %{}
  defp object_field(value, _where) when is_map(value), do: value
  defp object_field(_value, where), do: fail("plugin: manifest: #{where} must be an object")

  defp string_field(value, _where) when is_binary(value), do: value
  defp string_field(_value, where), do: fail("plugin: manifest: #{where} must be a string")

  defp integer_field(value, _where) when is_integer(value), do: value

  defp integer_field(value, where) when is_float(value) do
    if value == Float.round(value) do
      trunc(value)
    else
      fail("plugin: manifest: #{where} must be an integer")
    end
  end

  defp integer_field(_value, where), do: fail("plugin: manifest: #{where} must be an integer")

  defp text_present?(value), do: is_binary(value) and value != ""

  defp valid_reverse_dns?(id) do
    parts = String.split(id, ".")

    if length(parts) < 2 do
      false
    else
      Enum.all?(parts, fn part ->
        part != "" and byte_size(part) <= 63 and
          lower_alnum?(String.first(part)) and lower_alnum?(String.last(part)) and
          String.match?(part, ~r/^[a-z0-9-]+$/)
      end)
    end
  end

  defp lower_alnum?(character) when is_binary(character) do
    character in String.graphemes("abcdefghijklmnopqrstuvwxyz0123456789")
  end

  defp lower_alnum?(_), do: false

  defp valid_semver?(version) do
    core =
      version
      |> String.split("-", parts: 2)
      |> hd()
      |> String.split("+", parts: 2)
      |> hd()

    parts = String.split(core, ".")

    length(parts) == 3 and
      Enum.all?(parts, fn part ->
        part != "" and
          not (byte_size(part) > 1 and String.starts_with?(part, "0")) and
          String.match?(part, ~r/^[0-9]+$/)
      end)
  end
end
