require 'praxo'

module RetryExample
  M = Praxo::Models
  RETRYABLE = ['MODEL_UNAVAILABLE'].freeze

  class FlakyModel
    attr_reader :calls

    def initialize(failures)
      @failures = failures
      @calls = 0
    end

    def generate(_request)
      @calls += 1
      if @calls <= @failures
        raise Praxo::Error.new('MODEL_UNAVAILABLE', 'temporary outage')
      end
      M.response(message: M.message_assistant('status: green'))
    end
  end

  class RetryModel
    def initialize(model, max_attempts = 3)
      @model = model
      @max_attempts = max_attempts
    end

    def generate(request)
      last = nil
      (1..@max_attempts).each do |attempt|
        begin
          return @model.generate(request)
        rescue Praxo::Error => error
          last = error
          raise if !RETRYABLE.include?(error.code) || attempt == @max_attempts
        end
      end
      raise last
    end
  end

  def self.run(model, max_attempts = 3)
    options = Praxo::Agent::AgentOptions.new(RetryModel.new(model, max_attempts))
    options.max_steps = 2
    Praxo::Agent.run_agent(
      options, M.session(id: 'retry'), 'Check the status.'
    ).output
  end
end
