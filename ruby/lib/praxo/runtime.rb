require_relative 'errors'
require_relative 'json'
require_relative 'models'

module Praxo
  module Runtime
    class MultiSink
      def initialize(sinks)
        @sinks = sinks
      end

      def emit(event)
        @sinks.each { |sink| sink.emit(event) }
      end
    end

    class FilterSink
      def initialize(sink, predicate)
        @sink = sink
        @predicate = predicate
      end

      def emit(event)
        @sink.emit(event) if @predicate.call(event)
      end
    end

    class MemoryStore
      def initialize
        @records = Hash.new { |hash, key| hash[key] = [] }
        @sequence = 0
      end

      def put(session_id, record)
        if record.id.nil? || record.id.empty?
          record.id = "mem-#{(Time.now.to_f * 1000).to_i}-#{@sequence}"
          @sequence += 1
        end
        if record.created_at.nil?
          record.created_at = Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ')
        end
        @records[session_id] << record
        record
      end

      def search(session_id, query, limit)
        needle = query.to_s.strip.downcase
        matches = @records[session_id].select do |record|
          needle.empty? || record.content.to_s.downcase.include?(needle)
        end
        matches.sort_by! { |record| record.created_at.to_s }.reverse!
        limit.positive? ? matches.first(limit) : matches
      end
    end

    class CheckpointAllowlist
      def initialize
        @registered = {}
      end

      def register(type)
        Praxo.error('CHECKPOINT_ERROR', 'checkpoint: type is required') if type.nil? || type.empty?
        @registered[type] = true
      end

      def marshal(type, value)
        unless @registered[type]
          Praxo.error('CHECKPOINT_TYPE_NOT_ALLOWED',
                      "checkpoint: payload type not allowed: #{type}")
        end
        Json.stringify({ 'type' => type, 'data' => value })
      end

      def unmarshal(data)
        envelope = Json.parse(data)
        Praxo.error('CHECKPOINT_ERROR', 'checkpoint: envelope must be an object') unless envelope.is_a?(Hash)
        type = envelope['type'].is_a?(String) ? envelope['type'] : ''
        unless @registered[type]
          Praxo.error('CHECKPOINT_TYPE_NOT_ALLOWED',
                      "checkpoint: payload type not allowed: #{type}")
        end
        envelope['data']
      end
    end

    class PathChecker
      def initialize(grants)
        @grants = grants.map do |grant|
          Models::PathGrant.new(root: resolve_path(grant.root), access: grant.access || 'read')
        end
      end

      def check(target, need)
        unless %w[read write readwrite].include?(need)
          Praxo.error('POLICY_ERROR', 'policy: invalid access')
        end
        return Models::Decision.new(allowed: false, reason: 'no allowed roots') if @grants.empty?
        resolved = resolve_path(target)
        matched = nil
        @grants.each do |grant|
          next unless within?(grant.root, resolved)
          matched = grant.root
          return Models::Decision.new(allowed: true, reason: "path within #{grant.root}") if allows?(grant.access, need)
        end
        Models::Decision.new(allowed: false, reason: matched ? 'insufficient grant' : 'outside roots')
      end

      def allowed?(target, need)
        check(target, need).allowed
      rescue Error
        false
      end

      private

      def resolve_path(value)
        absolute = File.expand_path(value.to_s)
        return File.realpath(absolute) if File.exist?(absolute)
        parent = File.dirname(absolute)
        return absolute if parent == absolute
        File.join(resolve_path(parent), File.basename(absolute))
      rescue StandardError
        absolute
      end

      def within?(root, target)
        root = root.tr('\\', '/').sub(%r{/+\z}, '')
        target = target.tr('\\', '/').sub(%r{/+\z}, '')
        if RbConfig::CONFIG['host_os'].match?(/mswin|mingw|cygwin/)
          root = root.downcase
          target = target.downcase
        end
        target == root || target.start_with?("#{root}/")
      end

      def allows?(grant, need)
        return true if need == 'read' && %w[read readwrite].include?(grant)
        return true if need == 'write' && %w[write readwrite].include?(grant)
        return true if need == 'readwrite' && grant == 'readwrite'
        false
      end
    end

    class ContextBudget
      attr_reader :max_tokens, :keep_recent

      def initialize(max_tokens: 0, keep_recent: 0)
        @max_tokens = max_tokens
        @keep_recent = keep_recent
      end

      def compact(messages)
        max = @max_tokens
        return [messages, true] if max <= 0 || Runtime.estimate_tokens(messages) <= max
        system = []
        rest = []
        messages.each do |message|
          if message.role == Models::SYSTEM
            next if message.content.to_s.start_with?('[context compacted:')
            system << message
          else
            rest << message
          end
        end
        if Runtime.estimate_tokens(system) > max
          return [[], false] if system.empty?
          first = system[0].dup
          first.content = Runtime.truncate_to_tokens(system[0].content.to_s, max - 4)
          system = [first]
          return [[], false] if Runtime.estimate_tokens(system) > max
        end
        keep = @keep_recent.positive? ? @keep_recent : 4
        start = [rest.length - keep, 0].max
        start -= 1 while start.positive? && rest[start].role == Models::TOOL
        marker = Models.message_text(
          Models::SYSTEM,
          "[context compacted: #{start} older messages omitted]"
        )
        kept = rest[start..] || []
        build = lambda do
          output = system.dup
          output << marker if start.positive?
          output.concat(kept)
          output
        end
        output = build.call
        while Runtime.estimate_tokens(output) > max && kept.length > 1
          break if kept[1].role == Models::TOOL
          kept.shift
          output = build.call
        end
        [output, Runtime.estimate_tokens(output) <= max]
      end
    end

    module_function

    def estimate_tokens(messages)
      total = 0
      messages.each do |message|
        total += 4 + message.content.to_s.length / 4
        total += message.tool_id.to_s.length / 4
        (message.content_blocks || []).each do |block|
          total += 4 + block.text.to_s.length / 4
          total += block.image_url.to_s.length / 4
          total += block.data.to_s.length / 4
        end
        (message.tool_calls || []).each do |call|
          total += 4 + call.name.to_s.length / 4
          total += Json.stringify(call.arguments || {}).length / 4
        end
      end
      total
    end

    def truncate_to_tokens(value, tokens)
      return '' if tokens <= 0
      limit = tokens * 4
      return value if value.length <= limit
      return value[0, limit] if limit <= 16
      "#{value[0, limit - 16]}\n[truncated]"
    end
  end
end
