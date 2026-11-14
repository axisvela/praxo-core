require 'praxo'

module LiveModel
  M = Praxo::Models

  class GetTimeTool
    attr_reader :name, :description, :parameters, :risk

    def initialize
      @name = 'get_time'
      @description = 'Return the current time in ISO 8601 format for the requested zone.'
      @risk = 'read'
      @parameters = {
        'type' => 'object',
        'properties' => {
          'zone' => {
            'type' => 'string',
            'enum' => %w[utc local],
            'description' => 'utc or local; defaults to utc'
          }
        }
      }
    end

    def invoke(arguments)
      zone = arguments['zone'] == 'local' ? Time.now.getlocal : Time.now.utc
      zone.iso8601
    end
  end

  def self.env_or(name, fallback)
    value = ENV[name]
    value.nil? || value.empty? ? fallback : value
  end

  def self.run
    base_url = env_or('PRAXO_BASE_URL', 'http://localhost:11434/v1')
    model_name = env_or('PRAXO_MODEL', 'qwen3.5:4b')
    prompt = env_or(
      'PRAXO_PROMPT',
      'What time is it? Use get_time with zone set to utc and reply with the time.'
    )

    registry = Praxo::Agent::ToolRegistry.new
    registry.register(GetTimeTool.new)

    options = Praxo::Agent::AgentOptions.new(
      Praxo::Adapters::OpenAICompatible.new(
        base_url: base_url,
        model: model_name,
        api_key: env_or('PRAXO_API_KEY', nil)
      )
    )
    options.tools = registry
    options.system_prompt =
      'You are a concise assistant. Use the provided tools when they help.'
    options.max_steps = 4
    options.allowed_tools = ['get_time']
    options.policy = lambda do |action|
      case action.kind
      when 'model.generate'
        M.decision(allowed: true)
      when 'tool.invoke'
        M.decision(
          allowed: action.tool_name == 'get_time',
          reason: 'only get_time is permitted'
        )
      else
        M.decision(allowed: false, reason: 'unsupported action')
      end
    end

    result = Praxo::Agent.run_agent(options, M.session(id: 'live-model'), prompt)
    puts result.output
  rescue StandardError => error
    warn "live model run failed: #{error.message}\n\n" \
         "Check PRAXO_BASE_URL (#{ENV.fetch('PRAXO_BASE_URL', 'http://localhost:11434/v1')}), " \
         "PRAXO_MODEL (#{ENV.fetch('PRAXO_MODEL', 'qwen3.5:4b')}), and PRAXO_API_KEY"
    exit 1
  end
end

LiveModel.run if $PROGRAM_NAME == __FILE__
