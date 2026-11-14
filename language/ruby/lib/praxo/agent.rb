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
          if tool.respond_to?(:spec)
            tool.spec
          else
            Models.tool_spec(
              name: tool.name,
              description: tool.description,
              parameters: tool.respond_to?(:parameters) ? tool.parameters : nil,
              risk: tool.respond_to?(:risk) ? tool.risk : nil
            )
          end
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

    INTERRUPT_APPROVE = 'approve'
    INTERRUPT_EDIT = 'edit'
    INTERRUPT_REJECT = 'reject'
    INTERRUPT_RESPOND = 'respond'

    RespondTool = Struct.new(:value) do
      def invoke(_arguments)
        value
      end
    end

    class AgentOptions
      attr_accessor :model, :tools, :events, :policy, :system_prompt, :context,
                    :max_steps, :max_tokens, :tool_choice, :middleware,
                    :allowed_tools, :cancellation, :on_stream,
                    :max_parallel_tools, :interrupt_on, :on_interrupt_decision,
                    :on_interrupt

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
        @middleware = []
        @allowed_tools = []
        @cancellation = nil
        @on_stream = nil
        @max_parallel_tools = 1
        @interrupt_on = []
        @on_interrupt_decision = nil
        @on_interrupt = nil
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
        entered = []
        begin
          before_run(options, entered, run_id, prompt)
        rescue StandardError => e
          after_run(options, entered, nil, e)
          raise
        end
        emit(options, 'run.started', session.id, run_id)
        emit_stream(options, Models.stream_part(
          run_id: run_id, session_id: session.id, kind: 'values',
          step: 0, data: prompt.to_s
        ))
        after_run_invoked = false
        begin
          (1..max_steps).each do |step|
            check_cancelled(options)
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
            check_cancelled(options)
            usage = usage.plus(response.usage || Models.usage)
            total = usage.input_tokens.to_i + usage.output_tokens.to_i
            if options.max_tokens.to_i.positive? && total > options.max_tokens
              Praxo.error('AGENT_MAX_TOKENS', 'token budget')
            end
            message = response.message
            messages << message
            calls = message.tool_calls || []
            if calls.empty?
              result = Models.run_result(
                run_id: run_id, output: message.content.to_s, steps: step,
                usage: usage
              )
              emit_stream(options, Models.stream_part(
                run_id: run_id, session_id: session.id, kind: 'messages',
                step: step, data: message.content.to_s
              ))
              after_run_invoked = true
              cleanup_error = after_run(options, entered, result, nil)
              raise cleanup_error if cleanup_error
              emit(options, 'run.completed', session.id, run_id)
              return result
            end
            messages.concat(invoke_tools(options, calls, run_id, session.id))
          end
          Praxo.error('AGENT_MAX_STEPS', 'maximum steps')
        rescue StandardError => e
          after_run(options, entered, nil, e) unless after_run_invoked
          emit(options, 'run.failed', session.id, run_id, { 'error' => e.message })
          raise
        end
      end

      private

      def invoke_tools(options, calls, run_id, session_id)
        limit = [options.max_parallel_tools.to_i, 1].max
        results = []
        calls.each_slice(limit) do |batch|
          check_cancelled(options)
          prepared = batch.map do |call|
            prepare_tool(options, call, run_id, session_id)
          end
          if limit <= 1
            prepared.each do |tool, call|
              results << execute_tool(tool, call)
              check_cancelled(options)
            end
          else
            outcomes = prepared.map do |tool, call|
              Thread.new do
                begin
                  [:ok, execute_tool(tool, call)]
                rescue StandardError => caught
                  [:error, caught]
                end
              end
            end.map(&:value)
            outcomes.each do |status, payload|
              raise payload if status == :error
              results << payload
            end
            check_cancelled(options)
          end
        end
        results
      end

      def invoke_tool(options, call, run_id, session_id)
        tool, prepared = prepare_tool(options, call, run_id, session_id)
        execute_tool(tool, prepared)
      end

      def prepare_tool(options, call, run_id, session_id)
        original_name = call.name
        original_arguments = call.arguments
        unless allowed?(options, original_name)
          Praxo.error('AGENT_TOOL_NOT_ALLOWED', "tool #{original_name} is not allowed")
        end
        authorize(options, Models.action(
          kind: 'tool.invoke', session_id: session_id,
          tool_name: original_name, arguments: original_arguments
        ))
        options.middleware.each do |middleware|
          next unless middleware.respond_to?(:before_tool)
          call = middleware.before_tool(call) || call
        end
        unless allowed?(options, call.name)
          Praxo.error('AGENT_TOOL_NOT_ALLOWED', "tool #{call.name} is not allowed")
        end
        interrupt = apply_interrupt(options, call, run_id, session_id)
        call = interrupt[:call]
        return [RespondTool.new(interrupt[:value]), call] if interrupt[:skip]
        if call.name != original_name || call.arguments != original_arguments
          authorize(options, Models.action(
            kind: 'tool.invoke', session_id: session_id,
            tool_name: call.name, arguments: call.arguments
          ))
        end
        Praxo.error('TOOL_NOT_FOUND', 'tool is not registered') unless options.tools
        tool = options.tools.get(call.name)
        emit(options, 'tool.call', session_id, run_id,
             { 'name' => call.name, 'arguments' => call.arguments || {} })
        [tool, call]
      end

      def apply_interrupt(options, call, run_id, session_id)
        return { call: call, skip: false } unless options.interrupt_on.include?(call.name)
        if options.on_interrupt_decision.nil? && options.on_interrupt.nil?
          Praxo.error('AGENT_INTERRUPT_UNHANDLED',
                      'agent: approval handler not configured')
        end
        emit(options, 'tool.interrupt', session_id, run_id,
             { 'name' => call.name, 'arguments' => call.arguments || {} })
        interrupt = Models.interrupt(
          run_id: run_id, session_id: session_id, call: call
        )
        if options.on_interrupt_decision
          decision = options.on_interrupt_decision.call(interrupt)
          case decision.action
          when INTERRUPT_APPROVE
            return { call: call, skip: false }
          when INTERRUPT_EDIT
            if decision.arguments.nil?
              Praxo.error('AGENT_INTERRUPT_DECISION_INVALID',
                          'agent: edit requires arguments')
            end
            call.arguments = decision.arguments
            return { call: call, skip: false }
          when INTERRUPT_REJECT
            Praxo.error('AGENT_APPROVAL_DENIED',
                        "agent: tool call denied by approval: #{call.name}: " \
                        "#{decision.reason}")
          when INTERRUPT_RESPOND
            return { call: call, skip: true,
                     value: decision.response || '' }
          else
            Praxo.error('AGENT_INTERRUPT_DECISION_INVALID',
                        "agent: invalid interrupt decision: #{decision.action}")
          end
        end
        unless options.on_interrupt.call(interrupt)
          Praxo.error('AGENT_APPROVAL_DENIED',
                      "agent: tool call denied by approval: #{call.name}")
        end
        { call: call, skip: false }
      end

      def execute_tool(tool, call)
        value = tool.invoke(call.arguments || {})
        Models.message_tool(Json.stringify(value), call.id.to_s)
      end

      def check_cancelled(options)
        return unless options.cancellation
        cancelled = if options.cancellation.respond_to?(:cancelled?)
                      options.cancellation.cancelled?
                    elsif options.cancellation.respond_to?(:call)
                      options.cancellation.call
                    else
                      options.cancellation
                    end
        Praxo.error('AGENT_CANCELLED', 'run cancelled') if cancelled
      end

      def emit_stream(options, part)
        return unless options.on_stream
        options.on_stream.call(part)
      end

      def allowed?(options, name)
        options.allowed_tools.empty? || options.allowed_tools.include?(name)
      end

      def before_run(options, entered, run_id, prompt)
        state = { run_id: run_id, prompt: prompt }
        options.middleware.each do |middleware|
          entered << middleware
          middleware.before_run(state) if middleware.respond_to?(:before_run)
        end
      end

      def after_run(options, entered, result, error)
        first_error = nil
        entered.each do |middleware|
          next unless middleware.respond_to?(:after_run)
          begin
            middleware.after_run(result, error)
          rescue StandardError => caught
            first_error ||= caught
          end
        end
        first_error
      end

      def authorize(options, action)
        return unless options.policy
        decision = options.policy.call(action)
        Praxo.error('AGENT_POLICY_DENIED', 'policy denied the action') unless decision&.allowed
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
