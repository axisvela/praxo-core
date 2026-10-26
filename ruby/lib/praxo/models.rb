module Praxo
  module Models
    SYSTEM = 'system'
    USER = 'user'
    ASSISTANT = 'assistant'
    TOOL = 'tool'

    STREAM_KINDS = %w[values updates messages tasks debug checkpoint].freeze

    ContentBlock = Struct.new(:type, :text, :image_url, :data, keyword_init: true)
    ToolCall = Struct.new(:id, :name, :arguments, keyword_init: true)
    ToolSpec = Struct.new(:name, :description, :parameters, :risk, keyword_init: true)
    Message = Struct.new(:role, :content, :content_blocks, :tool_calls, :tool_id, keyword_init: true)
    Usage = Struct.new(:input_tokens, :output_tokens, :cached_tokens, keyword_init: true) do
      def plus(other)
        Usage.new(
          input_tokens: input_tokens.to_i + other.input_tokens.to_i,
          output_tokens: output_tokens.to_i + other.output_tokens.to_i,
          cached_tokens: cached_tokens.to_i + other.cached_tokens.to_i
        )
      end
    end
    Request = Struct.new(:messages, :tools, :tool_choice, :response_format, :temperature, keyword_init: true)
    Response = Struct.new(:message, :usage, :finish_reason, keyword_init: true)
    Session = Struct.new(:id, :messages, keyword_init: true)
    RunResult = Struct.new(:run_id, :output, :steps, :usage, keyword_init: true)
    MemoryRecord = Struct.new(:id, :frame, :content, :created_at, keyword_init: true)
    PathGrant = Struct.new(:root, :access, keyword_init: true)
    Action = Struct.new(:kind, :session_id, :tool_name, :arguments, keyword_init: true)
    Decision = Struct.new(:allowed, :reason, keyword_init: true)
    Event = Struct.new(:type, :session_id, :run_id, :data, keyword_init: true)

    module_function

    def content_block(**args)
      ContentBlock.new(
        type: args[:type] || 'text',
        text: args[:text],
        image_url: args[:image_url],
        data: args[:data]
      )
    end

    def tool_call(**args)
      ToolCall.new(
        id: args[:id] || '',
        name: args[:name] || '',
        arguments: args[:arguments] || {}
      )
    end

    def message(**args)
      Message.new(
        role: args[:role] || USER,
        content: args[:content],
        content_blocks: args[:content_blocks] || [],
        tool_calls: args[:tool_calls] || [],
        tool_id: args[:tool_id]
      )
    end

    def message_text(role, content)
      message(role: role, content: content)
    end

    def message_assistant(content, tool_calls = [])
      message(role: ASSISTANT, content: content, tool_calls: tool_calls)
    end

    def message_tool(content, tool_id)
      message(role: TOOL, content: content, tool_id: tool_id)
    end

    def tool_spec(**args)
      ToolSpec.new(
        name: args[:name] || '',
        description: args[:description] || '',
        parameters: args[:parameters],
        risk: args[:risk]
      )
    end

    def usage(input_tokens: 0, output_tokens: 0, cached_tokens: 0)
      Usage.new(input_tokens: input_tokens, output_tokens: output_tokens,
                cached_tokens: cached_tokens)
    end

    def request(**args)
      Request.new(
        messages: args[:messages] || [],
        tools: args[:tools] || [],
        tool_choice: args[:tool_choice],
        response_format: args[:response_format],
        temperature: args[:temperature] || 0
      )
    end

    def response(message:, usage: nil, finish_reason: nil)
      Response.new(message: message, usage: usage || Praxo::Models.usage,
                   finish_reason: finish_reason)
    end

    def session(id:, messages: [])
      Session.new(id: id, messages: messages)
    end

    def run_result(run_id:, output:, steps:, usage:)
      RunResult.new(run_id: run_id, output: output, steps: steps, usage: usage)
    end

    def memory_record(**args)
      MemoryRecord.new(
        id: args[:id] || '',
        frame: args[:frame] || '',
        content: args[:content] || '',
        created_at: args[:created_at]
      )
    end

    def event(type:, session_id:, run_id: nil, data: nil)
      Event.new(type: type, session_id: session_id, run_id: run_id, data: data)
    end

    def action(kind:, session_id:, tool_name: nil, arguments: nil)
      Action.new(kind: kind, session_id: session_id, tool_name: tool_name,
                 arguments: arguments)
    end

    def decision(allowed:, reason: '')
      Decision.new(allowed: allowed, reason: reason)
    end

    def message_wire(message)
      out = { 'role' => message.role }
      out['content'] = message.content unless message.content.nil?
      unless message.content_blocks.nil? || message.content_blocks.empty?
        out['contentBlocks'] = message.content_blocks.map do |block|
          wire = { 'type' => block.type }
          wire['text'] = block.text unless block.text.nil?
          wire['image_url'] = block.image_url unless block.image_url.nil?
          wire['data'] = block.data unless block.data.nil?
          wire
        end
      end
      unless message.tool_calls.nil? || message.tool_calls.empty?
        out['toolCalls'] = message.tool_calls.map do |call|
          { 'id' => call.id, 'name' => call.name, 'arguments' => call.arguments }
        end
      end
      out['toolId'] = message.tool_id unless message.tool_id.nil?
      out
    end
  end
end
