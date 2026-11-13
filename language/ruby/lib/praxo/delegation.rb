require_relative 'errors'

module Praxo
  module Delegation
    SubagentRequest = Struct.new(
      :parent_session_id, :agent_id, :prompt, :context, :mode, :history,
      keyword_init: true
    )
    SubagentResult = Struct.new(
      :task_id, :agent_id, :output, :usage, keyword_init: true
    )
    SubagentTask = Struct.new(
      :id, :parent_session_id, :agent_id, :mode, :status, :output, :error,
      :created_at, :updated_at, keyword_init: true
    )

    class SubagentManager
      TERMINAL = %w[completed failed canceled].freeze

      def initialize(runner)
        @runner = runner
        @tasks = {}
        @mutex = Mutex.new
        @condition = ConditionVariable.new
        @sequence = 0
      end

      def launch(request)
        raise Praxo::Error.new('SUBAGENT_INVALID', 'agent: subagent runner is required') if @runner.nil?

        parent = request.parent_session_id.to_s
        agent = request.agent_id.to_s
        if parent.empty? || agent.empty?
          raise Praxo::Error.new(
            'SUBAGENT_INVALID',
            'agent: subagent parent session and agent id are required'
          )
        end
        id = @mutex.synchronize { @sequence += 1; "subagent-#{@sequence}" }
        now = timestamp
        task = SubagentTask.new(
          id: id, parent_session_id: parent, agent_id: agent,
          mode: request.mode || 'isolated', status: 'queued',
          output: '', error: '', created_at: now, updated_at: now
        )
        @mutex.synchronize { @tasks[id] = { task: task, done: false } }
        Thread.new { execute(id, request) }
        copy(task)
      end

      def check(task_id)
        @mutex.synchronize do
          state = @tasks[task_id]
          state.nil? ? nil : copy(state[:task])
        end
      end

      def wait(task_id, timeout = nil)
        deadline = timeout.nil? ? nil : Time.now + timeout
        @mutex.synchronize do
          state = @tasks[task_id]
          raise Praxo::Error.new('SUBAGENT_NOT_FOUND', "agent: unknown subagent task \"#{task_id}\"") if state.nil?

          until state[:done]
            if deadline.nil?
              @condition.wait(@mutex)
            else
              remaining = deadline - Time.now
              if remaining <= 0
                raise Praxo::Error.new(
                  'SUBAGENT_TIMEOUT',
                  'agent: subagent wait timed out'
                )
              end
              @condition.wait(@mutex, remaining)
            end
          end
          copy(state[:task])
        end
      end

      def update(task_id, prompt)
        unless @runner.respond_to?(:update)
          raise Praxo::Error.new(
            'SUBAGENT_UPDATE_UNSUPPORTED',
            'agent: subagent update unsupported'
          )
        end
        @mutex.synchronize do
          state = @tasks[task_id]
          raise Praxo::Error.new('SUBAGENT_NOT_FOUND', "agent: unknown subagent task \"#{task_id}\"") if state.nil?
          unless state[:task].status == 'running'
            raise Praxo::Error.new(
              'SUBAGENT_NOT_RUNNING',
              "agent: subagent task \"#{task_id}\" is not running"
            )
          end
        end
        @runner.update(task_id, prompt)
      end

      def cancel(task_id)
        @mutex.synchronize do
          state = @tasks[task_id]
          raise Praxo::Error.new('SUBAGENT_NOT_FOUND', "agent: unknown subagent task \"#{task_id}\"") if state.nil?
          return if TERMINAL.include?(state[:task].status)

          state[:task].status = 'canceled'
          state[:task].updated_at = timestamp
          state[:done] = true
          @condition.broadcast
        end
      end

      private

      def execute(task_id, request)
        set(task_id, 'running')
        result = @runner.run(request)
        set(task_id, 'completed', output: result.output.to_s)
      rescue StandardError => error
        set(task_id, 'failed', error: error.message)
      end

      def set(task_id, status, output: '', error: '')
        @mutex.synchronize do
          state = @tasks[task_id]
          return if state.nil? || TERMINAL.include?(state[:task].status)

          state[:task].status = status
          state[:task].output = output
          state[:task].error = error
          state[:task].updated_at = timestamp
          if TERMINAL.include?(status)
            state[:done] = true
            @condition.broadcast
          end
        end
      end

      def copy(task)
        SubagentTask.new(**task.to_h)
      end

      def timestamp
        Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ')
      end
    end
  end
end
