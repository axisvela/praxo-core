require_relative 'errors'
require_relative 'json'

module Praxo
  module Plugin
    PluginManifest = Struct.new(
      :schema_version, :id, :version, :kind, :entrypoint, :protocol,
      :capabilities, :permissions, :limits, :isolation, :health, keyword_init: true
    )

    KINDS = %w[
      tool.provider.v1 model.provider.v1 policy.provider.v1
      memory.provider.v1 sandbox.provider.v1
    ].freeze
    TOP_KEYS = %w[
      schemaVersion id version kind entrypoint protocol capabilities permissions
      limits isolation health signature sbom
    ].freeze
    ENTRYPOINT_KEYS = %w[type command module image args dir].freeze
    PERMISSION_KEYS = %w[filesystem network env].freeze
    LIMIT_KEYS = %w[memoryMB cpuMillis timeoutMs maxInflight].freeze
    HEALTH_KEYS = %w[method intervalMs].freeze
    SIGNATURE_KEYS = %w[algorithm keyId].freeze

    module_function

    def parse_manifest(raw)
      Praxo.error('PLUGIN_INVALID', 'plugin: manifest is empty') if raw.nil? || raw.strip.empty?
      begin
        root = JSON.parse(raw)
      rescue JSON::ParserError => e
        Praxo.error('PLUGIN_INVALID', "plugin: manifest: #{e.message}")
      end
      Praxo.error('PLUGIN_INVALID', 'plugin: manifest must be an object') unless root.is_a?(Hash)
      check_keys(root, TOP_KEYS, 'manifest')
      schema_version = as_int(root['schemaVersion'], 'schemaVersion')
      if schema_version != 1
        Praxo.error('PLUGIN_INVALID',
                    "plugin: manifest: schemaVersion = #{schema_version}, want 1")
      end
      id = as_string(root['id'], 'id')
      unless id.match?(/\A(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\z/)
        Praxo.error('PLUGIN_INVALID', "plugin: manifest: id #{id} is not reverse-DNS")
      end
      version = as_string(root['version'], 'version')
      unless version.match?(/\A(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?\z/)
        Praxo.error('PLUGIN_INVALID', "plugin: manifest: version #{version} is not semver")
      end
      kind = as_string(root['kind'], 'kind')
      unless KINDS.include?(kind)
        Praxo.error('PLUGIN_INVALID', "plugin: manifest: kind #{kind} is not a known contract")
      end
      protocol = as_string(root['protocol'], 'protocol')
      unless protocol == 'jsonrpc-2'
        Praxo.error('PLUGIN_INVALID', "plugin: manifest: protocol = #{protocol}, want jsonrpc-2")
      end
      entrypoint = as_object(root['entrypoint'], 'entrypoint')
      check_keys(entrypoint, ENTRYPOINT_KEYS, 'entrypoint')
      entry_type = as_string(entrypoint['type'], 'entrypoint.type')
      required = case entry_type
                 when 'process' then 'command'
                 when 'wasm' then 'module'
                 when 'container' then 'image'
                 else
                   Praxo.error('PLUGIN_INVALID',
                               "plugin: manifest: unknown entrypoint type #{entry_type}")
                 end
      unless text_present(entrypoint[required])
        Praxo.error('PLUGIN_INVALID',
                    "plugin: manifest: #{entry_type} entrypoint requires #{required}")
      end
      isolation = as_string(root['isolation'], 'isolation')
      unless isolation == entry_type
        Praxo.error('PLUGIN_INVALID',
                    "plugin: manifest: isolation #{isolation} does not match entrypoint #{entry_type}")
      end
      permissions = as_object(root['permissions'], 'permissions')
      check_keys(permissions, PERMISSION_KEYS, 'permissions')
      limits = as_object(root['limits'], 'limits')
      check_keys(limits, LIMIT_KEYS, 'limits')
      limits.each do |key, value|
        Praxo.error('PLUGIN_INVALID', 'plugin: manifest: limits must not be negative') if as_int(value, "limits.#{key}").negative?
      end
      health = as_object(root['health'], 'health')
      check_keys(health, HEALTH_KEYS, 'health')
      if root.key?('signature')
        signature = as_object(root['signature'], 'signature')
        check_keys(signature, SIGNATURE_KEYS, 'signature')
        unless text_present(signature['algorithm']) && text_present(signature['keyId'])
          Praxo.error('PLUGIN_INVALID',
                      'plugin: manifest: signature requires algorithm and keyId')
        end
      end
      capabilities = []
      if root.key?('capabilities')
        unless root['capabilities'].is_a?(Array)
          Praxo.error('PLUGIN_INVALID', 'plugin: manifest: capabilities must be an array')
        end
        root['capabilities'].each do |item|
          capability = as_string(item, 'capabilities')
          Praxo.error('PLUGIN_INVALID', 'plugin: manifest: capability must not be empty') if capability.empty?
          Praxo.error('PLUGIN_INVALID', 'plugin: manifest: duplicate capability') if capabilities.include?(capability)
          capabilities << capability
        end
      end
      PluginManifest.new(
        schema_version: schema_version, id: id, version: version, kind: kind,
        entrypoint: entrypoint, protocol: protocol, capabilities: capabilities,
        permissions: permissions, limits: limits, isolation: isolation, health: health
      )
    end

    def check_keys(value, allowed, where)
      value.each_key do |key|
        unless allowed.include?(key)
          Praxo.error('PLUGIN_INVALID', "plugin: manifest: unknown field #{key} in #{where}")
        end
      end
    end

    def as_object(value, where)
      return {} if value.nil?
      unless value.is_a?(Hash)
        Praxo.error('PLUGIN_INVALID', "plugin: manifest: #{where} must be an object")
      end
      value
    end

    def as_string(value, where)
      unless value.is_a?(String)
        Praxo.error('PLUGIN_INVALID', "plugin: manifest: #{where} must be a string")
      end
      value
    end

    def as_int(value, where)
      unless value.is_a?(Numeric) && value.to_i == value
        Praxo.error('PLUGIN_INVALID', "plugin: manifest: #{where} must be an integer")
      end
      value.to_i
    end

    def text_present(value)
      value.is_a?(String) && !value.empty?
    end
  end
end
