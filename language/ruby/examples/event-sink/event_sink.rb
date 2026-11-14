require 'praxo'

module EventSinkExample
  M = Praxo::Models

  class RecordingSink
    attr_reader :events

    def initialize
      @events = []
    end

    def emit(event)
      @events << event
    end

    def types
      @events.map(&:type)
    end
  end

  class ToolThenAnswerModel
    def initialize
      @calls = 0
    end

    def generate(_request)
      @calls += 1
      if @calls == 1
        M.response(message: M.message_assistant('', [
          M.tool_call(id: 'call-1', name: 'lookup', arguments: { 'key' => 'status' })
        ]))
      else
        M.response(message: M.message_assistant('status: green'))
      end
    end
  end

  def self.create_agent(model, all_sink, tool_sink)
    tools = Praxo::Agent::ToolRegistry.new
    tools.register(Praxo::Agent::FuncTool.new(
      'lookup', 'Look up a small status value.',
      ->(args) { { 'key' => args['key'].to_s, 'value' => 'green' } }
    ))
    options = Praxo::Agent::AgentOptions.new(model)
    options.tools = tools
    options.events = Praxo::Runtime::MultiSink.new([
      all_sink,
      Praxo::Runtime::FilterSink.new(tool_sink, ->(event) { event.type == 'tool.call' })
    ])
    options.system_prompt = 'Use tools when asked for status.'
    options.max_steps = 3
    options
  end

  def self.run(all_sink, tool_sink, prompt = 'Check the status.')
    options = create_agent(ToolThenAnswerModel.new, all_sink, tool_sink)
    Praxo::Agent.run_agent(
      options, M.session(id: 'event-sink'), prompt
    ).output
  end
end
