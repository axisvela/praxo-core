require_relative 'errors'
require_relative 'json'

module Praxo
  module SSE
    module_function

    def parse(text)
      content = +''
      done = false
      text.to_s.each_line do |raw|
        line = raw.strip
        next unless line.start_with?('data:')
        chunk = line[5..].to_s.strip
        next if chunk.empty?
        if chunk == '[DONE]'
          done = true
          break
        end
        begin
          event = Json.parse(chunk)
        rescue StandardError
          Praxo.error('MODEL_STREAM', 'invalid SSE packet')
        end
        next unless event.is_a?(Hash)
        (event['choices'] || []).each do |choice|
          delta = choice['delta'] || {}
          content << delta['content'].to_s if delta['content']
          finish = choice['finish_reason']
          done = true if choice.key?('finish_reason') && !finish.nil?
        end
      end
      Praxo.error('MODEL_STREAM', 'stream ended before completion') unless done
      content
    end
  end
end
