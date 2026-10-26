require_relative 'errors'
require_relative 'json'
require_relative 'models'
require_relative 'runtime'

module Praxo
  module Agent
    class FuncTool
      attr_reader :name, :description

      def initialize(name, description, function)
        @name = name
        @description = description
        @function = function
      end

      def invoke(arguments)
        @function.call(arguments)
      end
    end

    class ToolRegistry
      def initialize
        @tools = {}
      end

      def register(tool)
        @tools[tool.name] = tool
        tool
      end

      def get(name)
        Praxo.error('TOOL_NOT_FOUND', "tool not found: #{name}") unless @tools.key?(name)
        @tools[name]
      end

      def specs
        @tools.values.map do |tool|
          Models.tool_spec(name: tool.name, description: tool.description)
        end.sort_by(&:name)
      end
    end

    class StaticModel
      def initialize(content)
        @content = content.to_s
      end

      def generate(_request)
        Models.response(message: Models.message_assistant(@content))
      end
    end

    class AgentOptions
      attr_accessor :model, :tools, :events, :policy, :system_prompt, :context,
                    :max_steps, :max_tokens, :tool_choice

      def initialize(model)
        @model = model
        @tools = nil
        @events = nil
        @policy = nil
        @system_prompt = ''
        @context = nil
        @max_steps = 8
        @max_tokens = 0
        @tool_choice = nil
      end
    end

    class Runner
      def initialize(options)
        @options = options
      end

      def run(session, prompt)
        options = @options
        max_steps = options.max_steps.to_i.positive? ? options.max_steps : 8
        run_id = "run-#{(Time.now.to_f * 1000).to_i}"
        messages = session.messages.dup
        unless options.system_prompt.to_s.empty?
          messages.unshift(Models.message_text(Models::SYSTEM, options.system_prompt))
        end
        messages << Models.message_text(Models::USER, prompt.to_s)
        usage = Models.usage
        emit(options, 'run.started', session.id, run_id)
        begin
          (1..max_steps).each do |step|
            authorize(options, Models.action(kind: 'model.generate', session_id: session.id))
            if options.context
              compacted, ok = options.context.compact(messages)
              Praxo.error('AGENT_CONTEXT_BUDGET', 'context budget') unless ok
              messages = compacted
            end
            request = Models.request(
              messages: messages,
              tools: options.tools ? options.tools.specs : [],
              tool_choice: options.tool_choice
            )
            response = options.model.generate(request)
            usage = usage.plus(response.usage || Models.usage)
            total = usage.input_tokens.to_i + usage.output_tokens.to_i
            if options.max_tokens.to_i.positive? && total > options.max_tokens
              Praxo.error('AGENT_MAX_TOKENS', 'token budget')
            end
            message = response.message
            messages << message
            calls = message.tool_calls || []
            if calls.empty?
              emit(options, 'run.completed', session.id, run_id)
              return Models.run_result(
                run_id: run_id, output: message.content.to_s, steps: step,
                usage: usage
              )
            end
            calls.each do |call|
              messages << invoke_tool(options, call, run_id, session.id)
            end
          end
          Praxo.error('AGENT_MAX_STEPS', 'maximum steps')
        rescue StandardError => e
          emit(options, 'run.failed', session.id, run_id, { 'error' => e.message })
          raise
        end
      end

      private

      def invoke_tool(options, call, run_id, session_id)
        authorize(options, Models.action(
          kind: 'tool.invoke', session_id: session_id,
          tool_name: call.name, arguments: call.arguments
        ))
        Praxo.error('TOOL_NOT_FOUND', 'tool is not registered') unless options.tools
        tool = options.tools.get(call.name)
        emit(options, 'tool.call', session_id, run_id,
             { 'name' => call.name, 'arguments' => call.arguments || {} })
        value = tool.invoke(call.arguments || {})
        Models.message_tool(Json.stringify(value), call.id.to_s)
      end

      def authorize(options, action)
        return unless options.policy
        decision = options.policy.call(action)
        Praxo.error('POLICY_ERROR', 'policy denied the action') unless decision&.allowed
      end

      def emit(options, type, session_id, run_id, data = nil)
        return unless options.events
        options.events.emit(Models.event(
          type: type, session_id: session_id, run_id: run_id, data: data
        ))
      end
    end

    module_function

    def run_agent(options, session, prompt)
      Runner.new(options).run(session, prompt)
    end
  end
end
