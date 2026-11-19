require 'base64'
require 'json'
require 'open3'
require 'securerandom'
require 'timeout'

require_relative 'errors'

module Praxo
  class PluginCallError < StandardError
    CODES = %w[
      CAPABILITY_DENIED NOT_ACTIVE NOT_FOUND INVALID_REQUEST TIMEOUT INTERNAL CANCELED
    ].freeze

    attr_reader :code

    def initialize(code, message = '')
      @code = CODES.include?(code) ? code : 'INTERNAL'
      super(message.empty? ? code : message)
    end
  end

  class PluginProcessConfig
    attr_accessor :plugin_id, :path, :args, :dir, :env, :token, :token_env_var,
                  :start_timeout, :invoke_timeout, :grace_period, :max_frame

    def initialize(plugin_id:, path:, args: [], dir: nil, env: nil, token: '',
                   token_env_var: 'PRAXOVELA_PLUGIN_TOKEN',
                   start_timeout: 10.0, invoke_timeout: 30.0, grace_period: 5.0,
                   max_frame: 8 << 20)
      @plugin_id = plugin_id
      @path = path
      @args = args
      @dir = dir
      @env = env
      @token = token
      @token_env_var = token_env_var
      @start_timeout = start_timeout
      @invoke_timeout = invoke_timeout
      @grace_period = grace_period
      @max_frame = max_frame
    end
  end

  class PluginProcessHost
    PROTOCOL_VERSION = 1
    CONTROL_SERVICE = 'host.control'
    HEALTH_METHOD = 'health'
    SHUTDOWN_METHOD = 'shutdown'
    CANCEL_METHOD = 'cancel'

    attr_reader :config, :plugin_id

    def initialize(config)
      raise ArgumentError, 'plugin: PluginID is required' if config.plugin_id.to_s.empty?
      raise ArgumentError, 'plugin: path is required' if config.path.to_s.empty?

      @config = config
      @plugin_id = config.plugin_id
      @token = config.token.to_s.empty? ? SecureRandom.hex(32) : config.token
      @seq = 0
      @active = false
      @stderr = +''
      @responses = Queue.new
    end

    def active?
      @active
    end

    def stderr_text
      @stderr.dup
    end

    def start
      raise 'plugin: host already started' if @process

      environment = (config.env || ENV.to_h).merge(config.token_env_var => @token)
      options = {}
      options[:chdir] = config.dir if config.dir
      @stdin, @stdout, @stderr_io, @wait = Open3.popen3(
        environment, config.path, *config.args, **options
      )
      @process = @wait
      @reader = Thread.new do
        begin
          @stdout.each_line do |line|
            @responses << line.strip
          end
        rescue IOError
          nil
        ensure
          @responses << nil
        end
      end
      @stderr_reader = Thread.new do
        begin
          @stderr_io.each_line do |line|
            @stderr << line if @stderr.length < (16 << 10)
          end
        rescue IOError
          nil
        end
      end
      call(CONTROL_SERVICE, HEALTH_METHOD, '', config.start_timeout)
      @active = true
    rescue StandardError
      terminate
      raise
    end

    def invoke(service, method, payload = '', timeout = nil)
      raise PluginCallError.new('NOT_ACTIVE', 'plugin: host is not active') unless @active

      call(service, method, payload, timeout || config.invoke_timeout)
    end

    def stop
      return unless @process

      begin
        call(CONTROL_SERVICE, SHUTDOWN_METHOD, '', config.grace_period) if @active
      rescue StandardError
        nil
      end
      @active = false
      begin
        Timeout.timeout(config.grace_period) { @wait.value }
      rescue Timeout::Error
        terminate
      end
      @process = nil
      @stdin = @stdout = @stderr_io = @wait = nil
      @reader&.kill
      @stderr_reader&.kill
    end

    private

    def call(service, method, payload, timeout)
      @seq += 1
      id = "req-#{@seq}"
      frame = {
        'id' => id,
        'version' => PROTOCOL_VERSION,
        'plugin_id' => config.plugin_id,
        'service' => service,
        'method' => method,
        'token' => @token,
        'payload' => Base64.strict_encode64(payload.to_s)
      }
      encoded = "#{JSON.generate(frame)}\n"
      raise PluginCallError.new('INVALID_REQUEST', 'plugin: request frame too large') if encoded.bytesize > config.max_frame

      @stdin.write(encoded)
      @stdin.flush
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + timeout
      loop do
        remaining = deadline - Process.clock_gettime(Process::CLOCK_MONOTONIC)
        if remaining <= 0
          send_cancel(id)
          terminate
          raise PluginCallError.new('TIMEOUT', 'plugin: invocation timed out')
        end
        begin
          line = Timeout.timeout(remaining) { @responses.pop }
        rescue Timeout::Error
          send_cancel(id)
          terminate
          raise PluginCallError.new('TIMEOUT', 'plugin: invocation timed out')
        end
        if line.nil?
          detail = stderr_text
          terminate
          raise PluginCallError.new('INTERNAL', detail.empty? ? 'plugin: process exited' : detail[0, 512])
        end
        response = begin
          JSON.parse(line)
        rescue JSON::ParserError
          next
        end
        next unless response['id'] == id

        unless response['ok'] == true
          raise PluginCallError.new(response['code'] || 'INTERNAL', response['message'] || '')
        end
        begin
          return Base64.strict_decode64(response['payload'] || '')
        rescue ArgumentError
          raise PluginCallError.new('INTERNAL', 'plugin: invalid payload')
        end
      end
    end

    def send_cancel(id)
      frame = {
        'id' => id,
        'version' => PROTOCOL_VERSION,
        'plugin_id' => config.plugin_id,
        'service' => CONTROL_SERVICE,
        'method' => CANCEL_METHOD,
        'token' => @token
      }
      @stdin&.write("#{JSON.generate(frame)}\n")
      @stdin&.flush
    rescue StandardError
      nil
    end

    def terminate
      @active = false
      begin
        Process.kill('KILL', @wait.pid) if @wait
      rescue StandardError
        nil
      end
      [@stdin, @stdout, @stderr_io].each { |io| io&.close rescue nil }
    end
  end
end
