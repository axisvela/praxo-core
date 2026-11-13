require 'net/http'
require 'time'
require 'uri'
require_relative '../errors'
require_relative '../json'

module Praxo
  module Adapters
    class OtelSink
      MAX_BODY = 512

      def initialize(endpoint: 'http://127.0.0.1:4318/v1/traces',
                     service_name: 'praxo-core', transport: nil,
                     allowed_data_keys: [], timeout: 10)
        @endpoint = endpoint.to_s.empty? ? 'http://127.0.0.1:4318/v1/traces' : endpoint
        @service_name = service_name.to_s.empty? ? 'praxo-core' : service_name
        @transport = transport
        @allowed_data_keys = Array(allowed_data_keys).map(&:to_s)
        @timeout = timeout
      end

      def emit(event)
        now = Time.now.utc
        stamp = otel_stamp(event, now)
        nanos = now.to_i * 1_000_000_000 + now.nsec
        data = event.data || {}
        key = [event.session_id, event.run_id, event.type,
               Json.stringify(data)].join('|')
        trace_id = [2166136261, 3307539480, 1540483477, 2807494644]
                   .map { |seed| hex32(fnv1a(key, seed)) }.join
        span_key = "#{key}|span"
        span_id = [2166136261, 3307539480]
                  .map { |seed| hex32(fnv1a(span_key, seed)) }.join
        attributes = [attribute('praxo.event.type', event.type)]
        if event.session_id && !event.session_id.empty?
          attributes << attribute('praxo.session.id', event.session_id)
        end
        if event.run_id && !event.run_id.empty?
          attributes << attribute('praxo.run.id', event.run_id)
        end
        attributes << attribute('praxo.event.at', stamp)
        @allowed_data_keys.each do |name|
          next unless data.key?(name)

          attributes << attribute("praxo.event.data.#{name}", otel_text(data[name]))
        end
        payload = {
          'resourceSpans' => [{
            'resource' => {
              'attributes' => [attribute('service.name', @service_name)]
            },
            'scopeSpans' => [{
              'scope' => { 'name' => 'praxo-core' },
              'spans' => [{
                'traceId' => trace_id,
                'spanId' => span_id,
                'name' => "praxo.#{event.type}",
                'kind' => 1,
                'startTimeUnixNano' => nanos.to_s,
                'endTimeUnixNano' => nanos.to_s,
                'attributes' => attributes
              }]
            }]
          }]
        }
        body = Json.stringify(payload)
        headers = { 'content-type' => 'application/json' }
        status, response_body = @transport ? @transport.call(@endpoint, body, headers) : post(body, headers)
        return if status.to_i >= 200 && status.to_i < 300

        bounded = response_body.to_s[0, MAX_BODY]
        Praxo.error('OTEL_HTTP', "otel: HTTP #{status}: #{bounded}")
      end

      private

      def otel_stamp(event, now)
        if event.respond_to?(:at) && event.at
          event.at.to_s
        else
          now.iso8601(9)
        end
      end

      def attribute(key, value)
        { 'key' => key, 'value' => { 'stringValue' => value.to_s } }
      end

      def otel_text(value)
        value.is_a?(String) ? value : Json.stringify(value)
      end

      def fnv1a(text, seed)
        value = seed & 0xFFFFFFFF
        text.to_s.bytes.each do |byte|
          value ^= byte
          value = (value * 16_777_619) & 0xFFFFFFFF
        end
        value
      end

      def hex32(value)
        format('%08x', value & 0xFFFFFFFF)
      end

      def post(body, headers)
        uri = URI.parse(@endpoint)
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
