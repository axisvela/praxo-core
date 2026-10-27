module Praxo
  class Error < StandardError
    attr_reader :code

    def initialize(code, message)
      @code = code
      super(message)
    end
  end

  def self.error(code, message)
    raise Error.new(code, message)
  end

  def self.error_code(error)
    error.is_a?(Error) ? error.code : ''
  end
end
