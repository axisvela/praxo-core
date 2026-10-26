require_relative 'json'

module Praxo
  module Toolcall
    ParsedToolCall = Struct.new(
      :call_id, :name, :input, :operation, :resource, :risk, :reason,
      :idempotency_key, keyword_init: true
    )

    module_function

    def parse_toolcall(content)
      call = parse_json_call(content) || parse_xml(content) || parse_tag(content) ||
             parse_plain(content)
      return nil unless call
      call.call_id = "tc-#{(Time.now.to_f * 1000).to_i}"
      call
    end

    def strip_markup(content)
      output = content.dup
      output.gsub!(%r{<tool_call\s+name="[^"]+"\s*>.*?(?:</tool_call>|$)}m, '')
      output.gsub!(%r{<tool_call_invoke>.*?(?:</tool_call_invoke>|$)}m, '')
      output.gsub!(%r{<[a-zA-Z][\w-]*(?:\.[\w-]+)+>\s*\{.*?(?:</[a-zA-Z][\w.-]*>|$)}m, '')
      output.gsub!(/\n{3,}/, "\n\n")
      output.strip
    end

    def parse_input_json(raw)
      begin
        value = JSON.parse(raw.strip)
        return value if value.is_a?(Hash)
      rescue JSON::ParserError
        nil
      end
      escaped = raw.gsub('\\', '\\\\\\\\')
      begin
        value = JSON.parse(escaped.strip)
        return value if value.is_a?(Hash)
      rescue JSON::ParserError
        return nil
      end
      nil
    end

    def parse_json_call(content)
      value = JSON.parse(content)
      return nil unless value.is_a?(Hash) && value['name'].is_a?(String) &&
                        !value['name'].empty?
      ParsedToolCall.new(
        name: value['name'],
        input: value['input'].is_a?(Hash) ? value['input'] : {},
        operation: value['operation'] || '',
        resource: value['resource'] || '',
        risk: value['risk'] || '',
        reason: value['reason'] || '',
        idempotency_key: value['idempotency_key'] || ''
      )
    rescue JSON::ParserError
      nil
    end

    def parse_xml(content)
      match = nil
      content.scan(%r{<tool_call\s+name="([^"]+)"\s*>\s*(.*?)\s*</tool_call>}m) do |name, raw|
        match = [name, raw]
      end
      return nil unless match
      input = parse_input_json(match[1])
      return nil unless input
      ParsedToolCall.new(name: match[0], input: input)
    end

    def parse_tag(content)
      match = nil
      content.scan(%r{<([a-zA-Z][\w-]*(?:\.[\w-]+)+)>\s*(\{.*?)\s*(?:</[a-zA-Z][\w.-]*>|$)}m) do |name, raw|
        match = [name, raw]
      end
      return nil unless match
      input = parse_input_json(match[1])
      return nil unless input
      ParsedToolCall.new(name: match[0], input: input)
    end

    def parse_plain(content)
      match = nil
      content.scan(/(?:^|\n)\s*([a-zA-Z][\w.-]*)\s+(\{.*\})\s*(?:\n|$)/m) do |name, raw|
        match = [name, raw]
      end
      return nil unless match && match[0].include?('.')
      input = parse_input_json(match[1])
      return nil unless input
      ParsedToolCall.new(name: match[0], input: input)
    end
  end
end
