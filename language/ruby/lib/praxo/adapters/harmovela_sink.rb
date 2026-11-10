require 'net/http'
require 'uri'
require_relative '../errors'
require_relative '../json'

module Praxo
  module Adapters
    class HarmovelaSink
      MAX_BODY = 1024

      def initialize(base_url:, source: nil, spec_version: nil, transport: nil, clock: nil, timeout: 10)
        @base_url = base_url.to_s.sub(%r{/+\z}, '')
        @source = source || 'praxo-core'
        @spec_version = spec_version || '0.2'
        @transport = transport
        @clock = clock || -> { Time.now.utc }
        @timeout = timeout
      end

      def emit(event)
        Praxo.error('HARMOVELA_URL', 'harmovela: base URL is required') if @base_url.empty?
        at = @clock.call.utc
        payload = (event.data || {}).dup
        if event.session_id && !event.session_id.empty?
          payload['session_id'] = event.session_id
        end
        payload['run_id'] = event.run_id if event.run_id && !event.run_id.empty?
        envelope = {
          'spec_version' => @spec_version,
          'id' => event_id(event, at),
          'type' => event.type,
          'source' => @source,
          'created_at' => created_at(at),
          'payload' => payload
        }
        body = Json.stringify(envelope)
        headers = { 'content-type' => 'application/json' }
        status, response_body = @transport ? @transport.call('/events', body, headers) : post(body, headers)
        return if status.to_i >= 200 && status.to_i < 300

        bounded = response_body.to_s[0, MAX_BODY]
        Praxo.error('HARMOVELA_HTTP', "harmovela: HTTP #{status}: #{bounded}")
      end

      private

      def event_id(event, at)
        prefix = event.run_id
        prefix = event.session_id if prefix.nil? || prefix.empty?
        prefix = 'event' if prefix.nil? || prefix.empty?
        "#{prefix}-#{at.to_i * 1_000_000_000 + at.nsec}"
      end

      def created_at(at)
        "#{at.strftime('%Y-%m-%dT%H:%M:%S')}.#{format('%09d', at.nsec)}Z"
      end

      def post(body, headers)
        uri = URI.parse(@base_url + '/events')
        request = Net::HTTP::Post.new(uri)
        headers.each { |key, value| request[key] = value }
        request.body = body
        response = Net::HTTP.start(
          uri.host,
          uri.port,
          use_ssl: uri.scheme == 'https',
          read_timeout: @timeout
        ) { |http| http.request(request) }
        [response.code.to_i, response.body.to_s]
      end
    end
  end
end
