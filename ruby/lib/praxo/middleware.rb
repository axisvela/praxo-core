require_relative 'errors'
require_relative 'json'
require_relative 'jsonschema'
require_relative 'models'

module Praxo
  module Middleware
    class PiiRedactor
      RULES = [
        [/[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}/, '[REDACTED:email]'],
        [/\b\d{3}-\d{2}-\d{4}\b/, '[REDACTED:ssn]'],
        [/\b(?:\d{4}[ -]?){3}\d{4}\b/, '[REDACTED:credit_card]']
      ].freeze

      def redact(text)
        output = text.to_s.dup
        RULES.each { |pattern, replacement| output.gsub!(pattern, replacement) }
        output
      end

      def redact_value(value)
        case value
        when String then redact(value)
        when Array then value.map { |item| redact_value(item) }
        when Hash then value.transform_values { |item| redact_value(item) }
        else value
        end
      end
    end

    class StructuredOutput
      def initialize(schema:, max_repairs: 0, repairer: nil)
        @schema = schema
        @max_repairs = max_repairs
        @repairer = repairer
      end

      def apply(text)
        output = text.to_s
        (0..@max_repairs).each do |attempt|
          begin
            data = Middleware.extract_json(output)
            return [output, nil] if JsonSchema.validate(@schema, data).empty?
          rescue StandardError
            nil
          end
          break if attempt == @max_repairs && @repairer.nil?
          break unless @repairer
          repaired = @repairer.call(output)
          break if repaired.nil? || repaired.strip.empty?
          output = repaired
        end
        [nil, 'AGENT_STRUCTURED_OUTPUT']
      end
    end

    class CallLimit
      def initialize(model_limit:, tool_limit:)
        @model_limit = model_limit
        @tool_limit = tool_limit
        @models = 0
        @tools = 0
      end

      def before_model
        @models += 1
        if @model_limit.positive? && @models > @model_limit
          Praxo.error('AGENT_MODEL_CALL_LIMIT', 'model call limit')
        end
      end

      def before_tool
        @tools += 1
        if @tool_limit.positive? && @tools > @tool_limit
          Praxo.error('AGENT_TOOL_CALL_LIMIT', 'tool call limit')
        end
      end
    end

    class ToolSelection
      def initialize(selected)
        @selected = selected.to_h { |name| [name, true] }
      end

      def filter(tools)
        tools.select { |tool| @selected[tool.name] }
      end

      def reject(name)
        Praxo.error('AGENT_TOOL_NOT_SELECTED', 'tool not selected') unless @selected[name]
      end
    end

    module_function

    def extract_json(text)
      value = text.to_s.strip
      if value.start_with?('```')
        newline = value.index("\n")
        value = value[(newline + 1)..] if newline
        value = value.gsub(/\A`+/, '').gsub(/`+\z/, '').strip
      end
      start = [value.index('{'), value.index('[')].compact.min
      raise Praxo::Error.new('AGENT_STRUCTURED_OUTPUT', 'output does not contain JSON') if start.nil?
      Json.parse(value[start..])
    end

    def redact(text)
      PiiRedactor.new.redact(text)
    end

    def redact_value(value)
      PiiRedactor.new.redact_value(value)
    end

    def structured_apply(schema, text, max_repairs = 0, repairer = nil)
      StructuredOutput.new(schema: schema, max_repairs: max_repairs, repairer: repairer).apply(text)
    end

    def fallback_model(fallback)
      lambda do |next_handler|
        lambda do |request|
          begin
            next_handler.call(request)
          rescue StandardError
            raise unless fallback
            fallback.call(request)
          end
        end
      end
    end
  end
end
