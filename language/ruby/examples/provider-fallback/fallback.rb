require 'praxo'

module ProviderFallbackExample
  M = Praxo::Models

  class StaticModel
    attr_reader :calls

    def initialize(content)
      @content = content
      @calls = 0
    end

    def generate(_request)
      @calls += 1
      M.response(message: M.message_assistant(@content))
    end
  end

  class FailingModel
    attr_reader :calls

    def initialize
      @calls = 0
    end

    def generate(_request)
      @calls += 1
      raise Praxo::Error.new('MODEL_UNAVAILABLE', 'primary unavailable')
    end
  end

  class FallbackModel
    def initialize(primary, fallback)
      @primary = primary
      @fallback = fallback
    end

    def generate(request)
      @primary.generate(request)
    rescue Praxo::Error => primary
      begin
        @fallback.generate(request)
      rescue Praxo::Error
        raise primary
      end
    end
  end

  def self.run(primary, fallback)
    model = FallbackModel.new(primary, fallback)
    options = Praxo::Agent::AgentOptions.new(model)
    options.max_steps = 2
    Praxo::Agent.run_agent(
      options, M.session(id: 'provider-fallback'), 'Say hello.'
    ).output
  end
end
