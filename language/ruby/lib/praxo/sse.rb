require_relative 'errors'
require_relative 'json'

module Praxo
  module SSE
    module_function

    def parse_response(text, on_delta)
      content = +''
      done = false
      finish = nil
      input_tokens = 0
      output_tokens = 0
      calls = {}
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
        usage = event['usage']
        if usage.is_a?(Hash)
          input_tokens = usage['prompt_tokens'].to_i
          output_tokens = usage['completion_tokens'].to_i
        end
        (event['choices'] || []).each do |choice|
          finish = choice['finish_reason'] if choice.key?('finish_reason') && !choice['finish_reason'].nil?
          delta = choice['delta'] || {}
          piece = delta['content']
          if piece && !piece.empty?
            content << piece
            on_delta.call(piece)
          end
          Array(delta['tool_calls']).each do |item|
            index = item['index'] || calls.size
            slot = calls[index] ||= { id: +'', name: +'', arguments: +'' }
            slot[:id] << item['id'].to_s if item['id']
            function = item['function'] || {}
            slot[:name] << function['name'].to_s if function['name']
            slot[:arguments] << function['arguments'].to_s if function['arguments']
          end
        end
        done = true if finish
      end
      Praxo.error('MODEL_STREAM', 'stream ended before completion') unless done
      tool_calls = calls.keys.sort.filter_map do |key|
        call = calls[key]
        next if call[:name].empty?

        arguments = {}
        unless call[:arguments].empty?
          begin
            arguments = Json.parse(call[:arguments])
          rescue StandardError
            Praxo.error('PROVIDER_JSON', 'provider returned invalid tool arguments')
          end
          unless arguments.is_a?(Hash)
            Praxo.error('PROVIDER_JSON', 'provider returned invalid tool arguments')
          end
        end
        Models.tool_call(id: call[:id], name: call[:name], arguments: arguments)
      end
      Models.response(
        message: Models.message(
          role: Models::ASSISTANT,
          content: content,
          tool_calls: tool_calls
        ),
        usage: Models.usage(input_tokens: input_tokens, output_tokens: output_tokens),
        finish_reason: finish
      )
    end

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
